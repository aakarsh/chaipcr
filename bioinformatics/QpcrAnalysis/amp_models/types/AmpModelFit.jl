## AmpModelFit.jl
##
## requires types_for_amp_models.jl
## for abstract type AmpModelFit
##
## requires AmpModel.jl
## for const ampmodels
##
## Author: Tom Price
## Date:   June 2019

import JuMP: Model
import DataStructures.OrderedDict


# types and constructors

struct SfcModelFit <: AmpModelFit
    coef_strs   ::Vector{String}
    coefs       ::Vector{Float_T}
    status      ::Symbol
    obj_val     ::AbstractFloat
    jmp_model   ::JuMP.Model
    init_coefs  ::OrderedDict{String,Float_T}
end

## Constructor method
SfcModelFit(;
    coef_strs   ::Vector{String}                =Vector{String}(),
    coefs       ::Vector{Float_T}               =zeros(0),
    status      ::Symbol                        = :not_fitted,
    obj_val     ::AbstractFloat                 =0.0,
    jmp_model   ::JuMP.Model                    =JuMP.Model(),
    init_coefs  ::OrderedDict{String,Float_T}   =OrderedDict{String,Float_T}()
) =
    SfcModelFit(coef_strs, coefs, status, obj_val, jmp_model, init_coefs)


struct MAK2Fit <: AmpModelFit
    max_d_idx   ::Int
    coef_strs   ::Vector{String}
    coefs       ::Vector{Float_T}
    status      ::Symbol
    obj_val     ::Float_T
    jmp_model   ::JuMP.Model
end

## Constructor method
MAK2Fit(;
    max_d_idx   ::Int               =0,
    coef_strs   ::Vector{String}    =Vector{String}(),
    coefs       ::Vector{Float_T}   =zeros(0),
    status      ::Symbol            = :not_fitted,
    obj_val     ::Float_T           =0.0,
    jmp_model   ::JuMP.Model        =JuMP.Model()
) =
    MAK2Fit(max_d_idx, coef_strs, coefs,
        status, obj_val, jmp_model)


struct MAK3Fit <: AmpModelFit
    max_d_idx   ::Int
    fb_start    ::Float_T
    bl_k_start  ::Float_T
    coef_strs   ::Vector{String}
    coefs       ::Vector{Float_T}
    status      ::Symbol
    obj_val     ::Float_T
    jmp_model   ::JuMP.Model
end

## Constructor method
MAK3Fit(;
    max_d_idx   ::Int               =0,
    fb_start    ::Float_T           =0.0,
    bl_k_start  ::Float_T           =0.0,
    coef_strs   ::Vector{String}    =Vector{String}(),
    coefs       ::Vector{Float_T}   =zeros(0),
    status      ::Symbol            = :not_fitted,
    obj_val     ::Float_T           =0.0,
    jmp_model   ::JuMP.Model        =JuMP.Model()
) =
    MAK3Fit(max_d_idx, fb_start, bl_k_start,
        coef_strs, coefs, status, obj_val, jmp_model)
    

struct MAKERGAUL3Fit <: AmpModelFit
    max_of_idx  ::Int
    coef_strs   ::Vector{String}
    coefs       ::Vector{Float_T}
    status      ::Symbol
    obj_val     ::Float_T
    jmp_model   ::JuMP.Model
end

## Constructor method
MAKERGAUL3Fit(;
    max_of_idx  ::Int               =0,
    coef_strs   ::Vector{String}    =Vector{String}(),
    coefs       ::Vector{Float_T}   =zeros(0),
    status      ::Symbol            = :not_fitted,
    obj_val     ::Float_T           =0.0,
    jmp_model   ::JuMP.Model        =JuMP.Model()
) =
    MAKERGAUL3Fit(max_of_idx, coef_strs, coefs,
        status, obj_val, jmp_model)


struct MAKERGAUL4Fit <: AmpModelFit
    max_of_idx  ::Int
    fb_start    ::Float_T
    bl_k_start  ::Float_T
    coef_strs   ::Vector{String}
    coefs       ::Vector{Float_T}
    status      ::Symbol
    obj_val     ::Float_T
    jmp_model   ::JuMP.Model
end

## Constructor method
MAKERGAUL4Fit(
    max_of_idx  ::Int               =0,
    fb_start    ::Float_T           =0.0,
    bl_k_start  ::Float_T           =0.0,
    coef_strs   ::Vector{String}    =Vector{String}(),
    coefs       ::Vector{Float_T}   =zeros(0),
    status      ::Symbol            = :not_fitted,
    obj_val     ::Float_T           =0.0,
    jmp_model   ::JuMP.Model        =JuMP.Model()
) =
    MAKERGAUL4Fit(max_of_idx, fb_start, bl_k_start,
        coef_strs, coefs, status, obj_val, jmp_model)


## constants

const ampmodelfits = subtypes(AmpModelFit)
const AmpModelFit_DICT = OrderedDict(
    zip(map(Symbol, ampmodels), ampmodelfits))

## NB keys(AmpModelFit_DICT) = all the possible values of am_key in amp.jl
