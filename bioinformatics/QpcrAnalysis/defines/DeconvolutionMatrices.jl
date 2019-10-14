#===============================================================================

    DeconvolutionMatrices.jl

    types for K matrices and their inverses
    used in deconvolution.jl

    Author: Tom Price
    Date:   June 2019

===============================================================================#

import StaticArrays: SVector, SMatrix



#===============================================================================
    struct >>
===============================================================================#

type DeconvolutionMatrices
    k_s             ::Vector{SMatrix{C,C,Float_T} where {C}}
    k_inv_vec       ::Vector{SMatrix{C,C,Float_T} where {C}}
    inv_note        ::String
end



#===============================================================================
    null constructor >>
===============================================================================#

function DeconvolutionMatrices(
    calibration_data    ::CalibrationData{<: NumberOfChannels, <: Real},
    calibration_args    ::CalibrationParameters
)
    const s = size(calibration_data.array)
    const w = s[1]
    const c = s[2]
    const v = calibration_args.k_method == well_proc_vec ? w : 1
    const empty_matrix = SMatrix{c,c,Float_T}(fill(NaN_T,c,c))
    DeconvolutionMatrices(
        SVector{v}(fill(empty_matrix,v)),
        SVector{w}(fill(empty_matrix,w)),
        "")
end



#===============================================================================
    constant >>
===============================================================================#

## this constant was previously loaded using
## JLD.load("$LOAD_FROM_DIR/defines/k4dcv_ip84_calib79n80n81_vec.jld")["k4dcv"]
const K4DCV =
    DeconvolutionMatrices(
        Vector{SMatrix{2,2,Float_T}}([
            [0.645552  0.152178 ;  0.354448  0.847822],
            [0.673361  0.209691 ;  0.326639  0.790309],
            [0.66636   0.0408344;  0.33364   0.959166],
            [0.627177  0.144452 ;  0.372823  0.855548],
            [0.696393  0.05625  ;  0.303607  0.94375 ],
            [0.686193  0.0750364;  0.313807  0.924964],
            [0.661831  0.015839 ;  0.338169  0.984161],
            [0.678446  0.145038 ;  0.321554  0.854962],
            [0.664971  0.079949 ;  0.335029  0.920051],
            [0.702946 -0.0320236;  0.297054  1.03202 ],
            [0.676903  0.096115 ;  0.323097  0.903885],
            [0.721044  0.15577  ;  0.278956  0.84423 ],
            [0.702459  0.0888078;  0.297541  0.911192],
            [0.728335  0.167087 ;  0.271665  0.832913],
            [0.649742  0.0844896;  0.350258  0.91551 ],
            [0.664093  0.0787242;  0.335907  0.921276]]),
        Vector{SMatrix{2,2,Float_T}}([
            [1.71842  -0.308443 ; -0.718416  1.30844 ],
            [1.70447  -0.452244 ; -0.704466  1.45224 ],
            [1.53338  -0.0652802; -0.533375  1.06528 ],
            [1.77233  -0.299243 ; -0.772331  1.29924 ],
            [1.47428  -0.0878709; -0.474279  1.08787 ],
            [1.51346  -0.122778 ; -0.513464  1.12278 ],
            [1.52349  -0.0245189; -0.523488  1.02452 ],
            [1.60283  -0.271908 ; -0.602828  1.27191 ],
            [1.57268  -0.13666  ; -0.572677  1.13666 ],
            [1.40417   0.0435714; -0.404172  0.956429],
            [1.55631  -0.165491 ; -0.556308  1.16549 ],
            [1.49349  -0.275565 ; -0.493488  1.27556 ],
            [1.48487  -0.14472  ; -0.484871  1.14472 ],
            [1.48404  -0.297706 ; -0.484038  1.29771 ],
            [1.61965  -0.149472 ; -0.619648  1.14947 ],
            [1.57384  -0.134486 ; -0.573837  1.13449 ]]),
        "")