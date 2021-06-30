"""
    function get_PTDF_thermal_constprice(args..., kwargs...)

Identify generators which cost function is a constant price, locate their buses and return
the corresponding PTDF matrix. Skips Slack generators, Generators which Active Power is
binding and Generators with non zero slope. Note: For a quadratic cost function of the form:
αPg²+ βPg + γ, a constant price generator will have the parameter α == 0.

# Arguments
- `sys::System`:                            Power system in p.u. (from PowerSystems.jl)
- `res::PowerSimulations.
    OperationsProblemResults`:              Results of the solved OPF for the system
                                             (from PowerSimulations.jl)
- `PTDF_matrix::Any`:                       PTDF matrix as a direct output from
                                            PTDF_matrix = PTDF(sys), see PowerSystems.jl

# Keywords
- `dual_gen_tol::Float64 = 1e-1`:           Tolerance to identify any binding generators

# Throws
- `ERROR`:                                  PTDF_matrix has no field data. The argument must
                                            be a direct output from PTDF_matrix = PTDF(sys)
                                            see PowerSystems.jl
"""
function get_PTDF_thermal_constprice(
    sys::System,
    res::PowerSimulations.OperationsProblemResults,
    PTDF_matrix ::Array;
    dual_gen_tol::Float64 = 1e-1
    )

    # Define elements
    gen_loc = 0
    gen_constprice = 0 #number of generators with constant price (counter starter)
    gens_thermal_constantprice_busnumber = Array{Int64}(undef, 0)
    nl,nb = size(PTDF_matrix)
    PTDF_constantprice = Array{Float64}(undef,(nl, 0))

    # Get all thermal Generators
    gens_thermal = get_components(ThermalStandard, sys)

    # Get dual variables from the OPF results
    dualPgub = get_duals(res)[:P_ub__ThermalStandard__RangeConstraint]
    dualPglb = get_duals(res)[:P_lb__ThermalStandard__RangeConstraint]

    # Identify Generators and Locate their Buses
    for gen_thermal in gens_thermal
        gen_loc = gen_loc +1
        if get_bustype(gen_thermal.bus) ≠ BusTypes.REF  #skips slack
            bindub = !isapprox(dualPgub[1,gen_loc], 0.0; atol = dual_gen_tol) #is binding?
            bindlb = !isapprox(dualPglb[1,gen_loc], 0.0; atol = dual_gen_tol) #is binding?
            if !bindub && !bindlb #skips binding Pg gens Dual = 0
                #Get gen costs parameters Gencost = αPg²+ βPg + γ
                α, β = get_cost(get_variable(get_operation_cost(gen_thermal)))
                γ = get_fixed(get_operation_cost(gen_thermal))
                if α == 0 && (β ≠ 0 || γ ≠ 0)#skips non zero slope
                    gen_constprice = gen_constprice +1
                    resize!(gens_thermal_constantprice_busnumber,gen_constprice)
                    gens_thermal_constantprice_busnumber[gen_constprice] =
                     gen_thermal.bus.number
                end
            end
        end
    end

    # Parse the PTDF matrix
    if gens_thermal_constantprice_busnumber == Any[]
        PTDF_constantprice = Array{Float64}(undef,(nl,0))
    else
        sort!(gens_thermal_constantprice_busnumber)
        PTDF_constantprice = PTDF_matrix[:,gens_thermal_constantprice_busnumber]
    end

    return gens_thermal_constantprice_busnumber, PTDF_constantprice
end
