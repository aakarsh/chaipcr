#===============================================================================

    amplification.jl

    amplification analysis

    issue:
    the code assumes only 1 step/ramp because the current data format
    does not allow us to break the fluorescence data down by step_id/ramp_id

===============================================================================#

import JSON: parse
import DataStructures.OrderedDict
import Ipopt: IpoptSolver #, NLoptSolver
import Memento: debug, warn, error
using Ipopt



#===============================================================================
    field names >>
===============================================================================#

const KWARGS_AMP_KEYS =
    ["min_reliable_cyc", "baseline_cyc_bounds", "ctrl_well_dict",
        CQ_METHOD_KEY, CATEG_WELL_VEC_KEY]
const KWARGS_RCQ_KEYS_DICT = Dict(
    "min_fluomax"   => :max_bsf_lb,
    "min_D1max"     => :max_dr1_lb,
    "min_D2max"     => :max_dr2_lb)
const AMP_VECTOR_OUTPUT_FIELDS =
    [:rbbs_3ary, :blsub_fluos, :coefs, :blsub_fitted, :dr1_pred, :dr2_pred]



#===============================================================================
    function definitions >>
===============================================================================#

## function called by dispatch()
## parses request body into AmpInput struct and calls amp_analysis()
"Generic function called by `dispatch`."
function act(
    ::Type{Val{amplification}},
    req_dict        ::Associative;
    out_format      ::OutputFormat = pre_json_output
)
    @inline str2sym(x) = isa(x, String) ? Symbol(x) : x
    #
    debug(logger, "at act(::Type{Val{amplification}})")
    const parsed_raw_data = try
        amp_parse_raw_data(req_dict)
    catch err
        return fail(logger, err; bt=true) |> out(out_format)
    end ## try
    #
    ## calibration data is required
    req_key = curry(haskey)(req_dict)
    if !(req_key(CALIBRATION_INFO_KEY) &&
        typeof(req_dict[CALIBRATION_INFO_KEY]) <: Associative)
            return fail(logger, ArgumentError(
                "no calibration information found")) |> out(out_format)
    end
    const calibration_data = CalibrationData(req_dict[CALIBRATION_INFO_KEY])
    #
    ## analysis parameters for model fitting
    const kw_amp = Dict{Symbol,Any}(
        map(KWARGS_AMP_KEYS |> sift(req_key)) do key
            if (key == CATEG_WELL_VEC_KEY)
                :categ_well_vec =>
                    map(req_dict[CATEG_WELL_VEC_KEY]) do x
                        const element = str2sym.(x)
                        (length(element[2]) == 0) ?
                            element :
                            Colon()
                    end ## do x
            elseif (key == CQ_METHOD_KEY)
                :cq_method => try
                    CqMethod(req_dict[CQ_METHOD_KEY])
                catch()
                    return fail(logger, ArgumentError("Cq method \"" *
                        req_dict[CQ_METHOD_KEY] * "\" not implemented");
                        bt=true) |> out(out_format)
                end ## try
            else
                Symbol(key) => str2sym.(req_dict[key])
            end ## if
        end) ## map
    #
    ## arguments for fit_baseline_model()
    const kw_bl =
        begin
            const baseline_method =
                req_key(BASELINE_METHOD_KEY) &&
               req_dict[BASELINE_METHOD_KEY]
            if      (baseline_method == SIGMOID_KEY)
                        Dict{Symbol,Any}(
                            :bl_method          =>  l4_enl,
                            :bl_fallback_func   =>  median)
            elseif  (baseline_method == LINEAR_KEY)
                        Dict{Symbol,Any}(
                            :bl_method          =>  lin_1ft,
                            :bl_fallback_func   =>  mean)
            elseif  (baseline_method == MEDIAN_KEY)
                        Dict{Symbol,Any}(
                            :bl_method          =>  take_the_median)
            else
                Dict{Symbol,Any}()
            end
        end
    #
    ## report_cq!() arguments
    const kw_rcq = Dict{Symbol,Any}(
        map(KWARGS_RCQ_KEYS_DICT |> keys |> collect |> sift(req_key)) do key
            KWARGS_RCQ_KEYS_DICT[key] => req_dict[key]
        end) ## map
    #
    ## create container for data and parameters
    ## to pass to amp_analysis()
    const amp_output = AmpOutputOption(out_format)
    const interface = AmpInput(
        parsed_raw_data...,
        calibration_data,
        IpoptSolver(print_level = 0, max_iter = 35),
        "",
        DEFAULT_AMP_DCV && parsed_raw_data[4] > 1, ## dcv && num_channels > 1
        DEFAULT_AMP_MODEL,
        # true,
        amp_output,
        roundoff(JSON_DIGITS);
        kw_bl...,
        kw_amp...,
        kw_rcq...,)
    const result = try
        ## issues:
        ## 1.
        ## the new code currently assumes only 1 step/ramp
        ## because as the request body is currently structured
        ## we cannot subset the fluorescence data by step_id/ramp_id
        ## 2.
        ## need to verify that the fluorescence data complies
        ## with the constraints imposed by max_cycle and well_constraint
        #
        # const sr_key =
        #     if      req_key(STEP_ID_KEY) STEP_ID_KEY
        #     elseif  req_key(RAMP_ID_KEY) RAMP_ID_KEY
        #     else throw(ArgumentError("no step/ramp information found"))
        #     end
        # const asrp_vec = [AmpStepRampProperties(:ramp, req_dict[sr_key], DEFAULT_cyc_nums)]
        # const sr_dict =
        #     OrderedDict(
        #         map([ asrp_vec[1] ]) do asrp
        #             join([asrp.step_or_ramp, asrp.id], "_") =>
        #                 amp_analysis(
        #                     # remove MySql dependency
        #                     # db_conn, exp_id, asrp, calib_info,
        #                     # fluo_well_nums, well_nums,
        #                     amp,
        #                     asrp,
        #                     out_format == json_output ? pre_json_output : out_format))
        #         end) ## do asrp
        # ## output
        # if (out_sr_dict)
        #     final_out = sr_dict
        # else
        #     const first_sr_out = first(values(sr_dict))
        #     final_out =
        #         OrderedDict(
        #             map(fieldnames(first_sr_out)) do key
        #                 key => getfield(first_sr_out, key)
        #             end)
        # end
        const first_sr_out = amp_analysis(interface)
        OrderedDict([
            map(fieldnames(first_sr_out)) do key
                key => getfield(first_sr_out, key)
            end...,
            :valid => true])
    catch err
        return fail(logger, err; bt=true) |> out(out_format)
    end ## try
    return result |> out(out_format)
end ## act(::Type{Val{amplification}})


#==============================================================================#


"Extract dimensions of raw amplification data, then format the raw data into a
3D array as required by `calibrate`."
function amp_parse_raw_data(req_dict ::Associative)
    const (cyc_nums, fluo_well_nums, channel_nums) =
        map([CYCLE_NUM_KEY, WELL_NUM_KEY, CHANNEL_KEY]) do key
            req_dict[RAW_DATA_KEY][key] |> unique             ## in order of appearance
        end
    const (num_cycs, num_fluo_wells, num_channels) =
        map(length, (cyc_nums, fluo_well_nums, channel_nums))
    #
    ## check that data are conformable to 3D array
    try
        assert(req_dict[RAW_DATA_KEY][CYCLE_NUM_KEY] ==
            repeat(
                cyc_nums,
                outer = num_fluo_wells * num_channels))
        assert(req_dict[RAW_DATA_KEY][WELL_NUM_KEY ] ==
            repeat(
                fluo_well_nums,
                inner = num_cycs,
                outer = num_channels))
        assert(req_dict[RAW_DATA_KEY][CHANNEL_KEY  ] ==
            repeat(
                channel_nums,
                inner = num_cycs * num_fluo_wells))
    catch()
        throw(AssertionError("The format of the fluorescence data does not " *
            "lend itself to transformation into a 3-dimensional array. " *
            "Please make sure that it is sorted by channel, well number, and cycle number."))
    end ## try
    #
    ## reshape to 3D array
    const F = typeof(req_dict[RAW_DATA_KEY][FLUORESCENCE_VALUE_KEY][1])
    const raw_data = ## formerly `fr_ary3`
        reshape(
            req_dict[RAW_DATA_KEY][FLUORESCENCE_VALUE_KEY],
            num_cycs, num_fluo_wells, num_channels)
    #
    ## rearrange data in sort order of each index
    const cyc_perm  = sortperm(cyc_nums)
    const well_perm = sortperm(fluo_well_nums)
    const chan_perm = sortperm(channel_nums)
    return (
        RawData{F}(raw_data[cyc_perm, well_perm, chan_perm]),
        num_cycs,
        num_fluo_wells,
        num_channels,
        cyc_nums[cyc_perm],
        fluo_well_nums[well_perm],
        channel_nums[chan_perm])
end ## amp_parse_raw_data()


#==============================================================================#


"Analyse amplification data via calls to `calibrate` and `get_fit_results`."
function amp_analysis(i ::AmpInput) # ; asrp ::AmpStepRampProperties)
    debug(logger, "at amp_analysis()")
    #
    ## deconvolute and normalize
    const calibration_results =
        calibrate(
            i.raw,
            i.calibration_data,
            i.fluo_well_nums,
            i.channel_nums;
            dcv = i.dcv,
            data_format = array)
    #
    ## initialize output
    o = AmpOutput(
        Val{i.amp_output},
        i,
        calibration_results...,
        # cq_method,
        DEFAULT_AMP_CT_FLUOS)
    #
    ## fit amplification models and report results
    if i.num_cycs <= 2
        warn(logger, "number of cycles $num_cycs <= 2: baseline subtraction " *
            "and Cq calculation will not be performed")
    else ## num_cycs > 2
        const baseline_cyc_bounds = check_bl_cyc_bounds(i, DEFAULT_AMP_BL_CYC_BOUNDS)
        o.ct_fluos = calc_ct_fluos(i, o, DEFAULT_AMP_CT_FLUOS, baseline_cyc_bounds)
        set_output_fields!(i, o, get_fit_results(i, o, baseline_cyc_bounds))
        set_qt_fluos!(i, o)
        set_report_cq!(i, o)
    end ## if
    #
    ## allelic discrimination
    # if dcv
    #     o.assignments_adj_labels_dict, o.agr_dict =
    #         process_ad(i, o)
    # end # if dcv
    #
    return o
end ## amp_analysis()


#==============================================================================#


"Calculate the amplification output field `ct_fluos`."
function calc_ct_fluos(
    i                       ::AmpInput,
    o                       ::AmpOutput,
    ct_fluos                ::AbstractVector,
    baseline_cyc_bounds     ::AbstractArray,
)
    debug(logger, "at calc_ct_fluos()")
    const ct_fluos_empty = fill(NaN, i.num_channels)
    (i.num_cycs <= 2)       && return ct_fluos
    (length(ct_fluos) > 0)  && return ct_fluos
    (i.cq_method != :ct)    && return ct_fluos_empty
    (i.amp_model != :SFC)   && return ct_fluos_empty
    ## else
    map(1:i.num_channels) do channel_i
        const fits =
            map(1:i.num_fluo_wells) do well_i
                const fluos = o.rbbs_3ary[:, well_i, channel_i]
                fit_amplification_model(
                    Val{SFCModel},
                    AmpCqFluoModelResults,
                    i,
                    fluos,
                    bl_cyc_bounds[well_i, channel_i],
                    DEFAULT_AMP_CT_FLUO_METHOD, ## cq_method
                    NaN) ## i.ct_fluo
            end ## do well_i
        fits |>
            mold(field(:quant_status)) |>
            find_idc_useful |>
            curry(getindex)(fits) |>
            mold(field(:cq_fluo)) |>
            median
    end ## do channel_i
end ## calc_ct_fluos()


## used in calc_ct_fluos()
@inline function find_idc_useful(postbl_stata ::AbstractVector)
    idc_useful = find(postbl_stata .== :Optimal)
    (length(idc_useful) > 0) && return idc_useful
    idc_useful = find(postbl_stata .== :UserLimit)
    (length(idc_useful) > 0) && return idc_useful
    return eachindex(postbl_stata)
end ## find_idc_useful()


#==============================================================================#


"Fit amplification model to data for each well and channel."
function get_fit_results(
    i                       ::AmpInput,
    o                       ::AmpOutput,
    bl_cyc_bounds           ::AbstractArray,
)
    function fit_model(wi ::Integer, ci ::Integer)
        debug(logger, "at fit_model($wi, $ci)")
        if isa(solver, Ipopt.IpoptSolver) && length(prefix) > 0
            const ipopt_file = string(join([prefix, ci, wi], '_')) * ".txt"
            push!(solver.options, (:output_file, ipopt_file))
        end
        const fluos = o.rbbs_3ary[:, wi, ci]
        fit_amplification_model(
            Val{i.amp_model},
            i.amp_model_results,
            i,
            fluos,
            bl_cyc_bounds[wi, ci],
            i.cq_method,
            o.ct_fluos[ci])
    end ## fit model()

    ## << end of function definition nested within set_fit_results!()
        
    debug(logger, "at set_fit_results!()")
    solver = i.solver
    const prefix = i.ipopt_print2file_prefix
    const fit_results =
        [
            fit_model(wi, ci)
            for wi in 1:i.num_fluo_wells, ci in 1:i.num_channels    ]
end ## set_fit_results!()


#==============================================================================#


"Format the results of the amplification analyses."
@inline function set_output_fields!(
    i                       ::AmpInput,
    o                       ::AmpOutput,
    results                 ::AbstractArray,
)
    debug(logger, "at set_output_fields!()")
    foreach(fieldnames(first(results))) do fieldname
        const T = eltype(getfield(o, fieldname))
        if fieldname in AMP_VECTOR_OUTPUT_FIELDS
            setfield!(o, fieldname,
                results |>
                moose(bless(Vector{T}) ∘ field(fieldname), hcat) |>
                morph(:, i.num_fluo_wells, i.num_channels))
        else
            setfield!(o, fieldname,
                results |> mold(bless(T) ∘ field(fieldname)))
        end ## if
    end ## next fieldname
    return nothing ## side effects only
end ## set_output_fields!()


#==============================================================================#


"Calculate the amplification analysis fields `qt_fluos` and `max_qt_fluo`, when
the output format is `long`."
function set_qt_fluos!(
    i                       ::AmpInput, 
    o                       ::AmpLongOutput, 
)
    debug(logger, "at set_qt_fluos!()")
    o.qt_fluos =
        [   quantile(o.blsub_fluos[:, well_i, channel_i], i.qt_prob)
            for well_i in 1:i.num_fluo_wells, channel_i in 1:i.num_channels ]
    o.max_qt_fluo = maximum(o.qt_fluos)
    return nothing ## side effects only
end ## set_qt_fluos!()


"Do nothing when the output format is `short`."
set_qt_fluos!(
    i                       ::AmpInput, 
    o                       ::AmpShortOutput,
) =
    nothing


#==============================================================================#


"Call `report_cq!` for each well and channel, when the output format is `long`."
function set_report_cq!(
    i                       ::AmpInput, 
    o                       ::AmpLongOutput, 
)
    debug(logger, "at set_report_cq!()")
    for well_i in 1:i.num_fluo_wells, channel_i in 1:i.num_channels
        report_cq!(i, o, well_i, channel_i)
    end
    return nothing ## side effects only
end ## set_report_cq!()


"Do nothing when the output format is `short`."
set_report_cq!(
    i                       ::AmpInput, 
    o                       ::AmpShortOutput,
) =
    nothing


"Report amplification output fields relating to the calculation of `cq`. "
function report_cq!(
    i                       ::AmpInput, 
    o                       ::AmpLongOutput,
    well_i                  ::Integer,
    channel_i               ::Integer,
)
    if i.before_128x
        max_dr1_lb, max_dr2_lb, max_bsf_lb = [i.max_dr1_lb, i.max_dr2_lb, i.max_bsf_lb] ./ 128
    else
        max_dr1_lb, max_dr2_lb, max_bsf_lb = i.max_dr1_lb, i.max_dr2_lb, i.max_bsf_lb
    end
    #
    const num_cycs = size(o.raw_data, 1)
    const (postbl_status, cq_raw, max_dr1, max_dr2) =
        map([ :postbl_status, :cq_raw, :max_dr1, :max_dr2 ]) do fieldname
            fieldname -> getfield(o, fieldname)[well_i, channel_i]
        end
    const max_bsf = maximum(o.blsub_fluos[:, well_i, channel_i])
    const b_ = o.coefs[1, well_i, channel_i]
    const (scaled_max_dr1, scaled_max_dr2, scaled_max_bsf) =
        [max_dr1, max_dr2, max_bsf] ./ o.max_qt_fluo
    const why_NaN =
        if postbl_status == :Error
            "postbl_status == :Error"
        elseif b_ > 0
            "b > 0"
        elseif o.cq_method == ct && o.cq_raw == AMP_CT_VAL_DOMAINERROR
            "DomainError when calculating Ct"
        elseif o.cq_raw <= 0.1 || o.cq_raw >= num_cycs
            "cq_raw <= 0.1 || cq_raw >= num_cycs"
        elseif max_dr1 < max_dr1_lb
            "max_dr1 $max_dr1 < max_dr1_lb $max_dr1_lb"
        elseif max_dr2 < max_dr2_lb
            "max_dr2 $max_dr2 < max_dr2_lb $max_dr2_lb"
        elseif max_bsf < max_bsf_lb
            "max_bsf $max_bsf < max_bsf_lb $max_bsf_lb"
        elseif scaled_max_dr1 < i.scaled_max_dr1_lb
            "scaled_max_dr1 $scaled_max_dr1 < scaled_max_dr1_lb $(i.scaled_max_dr1_lb)"
        elseif scaled_max_dr2 < i.scaled_max_dr2_lb
            "scaled_max_dr2 $scaled_max_dr2 < scaled_max_dr2_lb $(i.scaled_max_dr2_lb)"
        elseif scaled_max_bsf < i.scaled_max_bsf_lb
            "scaled_max_bsf $scaled_max_bsf < scaled_max_bsf_lb $(i.scaled_max_bsf_lb)"
        else
            ""
        end ## why_NaN
    (why_NaN != "") && (o.cq[well_i, channel_i] = NaN)
    #
    for tup in (
        (:max_bsf,        max_bsf),
        (:scaled_max_dr1, scaled_max_dr1),
        (:scaled_max_dr2, scaled_max_dr2),
        (:scaled_max_bsf, scaled_max_bsf),
        (:why_NaN,        why_NaN))
        getfield(o, tup[1])[well_i, channel_i] = tup[2]
    end
    return nothing ## side effects only
end ## report_cq!
