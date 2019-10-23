function instantiate_linear_equation_of_state(FT, α, β)
    eos = LinearEquationOfState(FT, α=α, β=β)
    return eos.α == FT(α) && eos.β == FT(β)
end

function instantiate_roquet_equations_of_state(FT, flavor; coeffs=nothing)
    eos = (coeffs == nothing ? RoquetIdealizedNonlinearEquationOfState(FT, flavor) :
                               RoquetIdealizedNonlinearEquationOfState(FT, flavor, polynomial_coeffs=coeffs))
    return typeof(eos.polynomial_coeffs.R₁₀₀) == FT
end

function instantiate_seawater_buoyancy(FT, EquationOfState) 
    buoyancy = SeawaterBuoyancy(FT, equation_of_state=EquationOfState(FT))
    return typeof(buoyancy.gravitational_acceleration) == FT
end

function density_perturbation_works(arch, FT, eos)
    grid = RegularCartesianGrid(FT, N=(3, 3, 3), L=(1, 1, 1))
    C = datatuple(TracerFields(arch, grid, (:T, :S)))
    density_anomaly = ρ′(2, 2, 2, grid, eos, C)
    return true
end

function buoyancy_frequency_squared_works(arch, FT, buoyancy)
    grid = RegularCartesianGrid(N=(3, 3, 3), L=(1, 1, 1))
    C = datatuple(TracerFields(arch, grid, required_tracers(buoyancy)))
    N² = buoyancy_frequency_squared(2, 2, 2, grid, buoyancy, C)
    return true
end

function thermal_expansion_works(arch, FT, eos)
    grid = RegularCartesianGrid(FT, N=(3, 3, 3), L=(1, 1, 1))
    C = datatuple(TracerFields(arch, grid, (:T, :S)))
    α = thermal_expansion(2, 2, 2, grid, eos, C)
    return true
end

function haline_contraction_works(arch, FT, eos)
    grid = RegularCartesianGrid(N=(3, 3, 3), L=(1, 1, 1))
    C = datatuple(TracerFields(arch, grid, (:T, :S)))
    β = haline_contraction(2, 2, 2, grid, eos, C)
    return true
end

@testset "Buoyancy" begin
    println("Testing buoyancy...")
    
    @testset "Equations of State" begin
        for FT in float_types
            @test instantiate_linear_equation_of_state(FT, 0.1, 0.3)

            testcoeffs = (R₀₁₀ = π, R₁₀₀ = ℯ, R₀₂₀ = 2π, R₀₁₁ = 2ℯ, R₂₀₀ = 3π, R₁₀₁ = 3ℯ, R₁₁₀ = 4π)
            for flavor in (:linear, :cabbeling, :cabbeling_thermobaricity, :freezing, :second_order)
                @test instantiate_roquet_equations_of_state(FT, flavor)
                @test instantiate_roquet_equations_of_state(FT, flavor, coeffs=testcoeffs)
            end

            for EOS in EquationsOfState
                @test instantiate_seawater_buoyancy(FT, EOS)
            end

            for arch in archs
                @test density_perturbation_works(arch, FT, RoquetIdealizedNonlinearEquationOfState())
            end

            for arch in archs
                for EOS in EquationsOfState
                    buoyancy = SeawaterBuoyancy(FT, equation_of_state=EOS(FT))
                    @test buoyancy_frequency_squared_works(arch, FT, buoyancy)
                end

                for buoyancy in (BuoyancyTracer(), nothing)
                    @test buoyancy_frequency_squared_works(arch, FT, buoyancy)
                end
            end

            for arch in archs
                for EOS in EquationsOfState 
                    @test thermal_expansion_works(arch, FT, EOS())
                    @test haline_contraction_works(arch, FT, EOS())
                end
            end
        end
    end
end