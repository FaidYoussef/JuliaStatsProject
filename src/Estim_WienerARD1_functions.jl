using Plots
import Plots: plot!, vline!
using LinearAlgebra
using Optim
using Statistics
using Distributions
using Random

mutable struct WienerProcess{T<:Number}
    mu::T
    sigma2::T
    timestep::T
    values::Vector{T}
    steps::Int
    times::Vector{T}

    # Constructeur pour initialiser le processus sans valeurs simulées
    function WienerProcess{T}(mu::T, sigma2::T, timestep::T, steps::Int) where T<:Number
        new{T}(mu, sigma2, timestep, Vector{T}(undef, steps + 1), steps, collect(0:timestep:steps * timestep))
    end
end

# Fonction pour simuler le processus de Wiener
function simulate!(wp::WienerProcess)
    sqrt_sigma2 = sqrt(wp.sigma2)
    wp.values = [0.0]
    normal_dist = Normal(0, 1)  # Définir une distribution normale standard
    for t in 1:wp.steps
        dt = wp.timestep
        dW = sqrt_sigma2 * sqrt(dt) * rand(normal_dist)
        new_value = wp.values[end] + wp.mu * dt + dW
        push!(wp.values, new_value)
    end
end

# Méthode pour tracer le processus de Wiener
function plot!(process::WienerProcess)
    # Tracer le processus de Wiener
    plot!(process.times, process.values, xlabel="Temps", ylabel="", label="Process de Wiener", 
    linestyle=:dash, markercolor=:blue)
    
    # Tracer la droite mu*t
    plot!(process.times, process.mu .* process.times, label="mu*t", linestyle=:dash)
end

mutable struct WienerARD1
    underlying_process::WienerProcess{Float64}
    rho::Float64
    maintenance_times::Vector{Float64}
    k::Int
    values::Vector{Vector{Float64}}
    new_times::Vector{Vector{Float64}}

    function WienerARD1(mu::Float64, sigma2::Float64, timestep::Float64, steps::Int, rho::Float64, maintenance_times::Vector{Float64})
        underlying_process = WienerProcess{Float64}(mu, sigma2, timestep, steps)
        simulate!(underlying_process)
        
        k = length(maintenance_times)
        
        # Initialize new_times array
        new_times = Vector{Vector{Float64}}()
        start_time = 0.0
        
        # Populate new_times with intervals up to each maintenance time
        for i in 1:length(maintenance_times)
            end_time = maintenance_times[i]
            push!(new_times,collect(start_time:timestep:end_time))
            start_time = end_time
        end
        
        # Last segment from last maintenance time to the end
        push!(new_times, collect(start_time:timestep:(steps * timestep)))
        
        new(underlying_process, rho, maintenance_times, k, Vector{Vector{Float64}}(), new_times)
    end
end

function simulate!(process::WienerARD1)
    
    # Créer un vecteur Y initialisé avec les valeurs de X
    Y = copy(process.underlying_process.values)
    
    # Modifier les valeurs de Y selon les règles spécifiées
    for i in 1:length(process.maintenance_times) - 1
        maintenance_time = process.maintenance_times[i]
        next_maintenance_time = process.maintenance_times[i+1]
        
        # Indices des temps entre deux instants de maintenance
        indices = findall(t -> t > maintenance_time && t <= next_maintenance_time, process.underlying_process.times)
        
        # Mettre à jour les valeurs de Y
        Y[indices] .-= process.rho .* process.underlying_process.values[indices[1] - 1]  
    end
    
    indices = findall(t -> t > process.maintenance_times[length(process.maintenance_times)], process.underlying_process.times)
    Y[indices] .-= process.rho .* process.underlying_process.values[indices[1] - 1]

    new_values = Float64[]

    last_before_maintenance = findlast(t -> t <= process.maintenance_times[1], process.underlying_process.times)

    if last_before_maintenance !== nothing
        # Concatenate the part before last_before_maintenance into new_values
        append!(new_values, Y[1:last_before_maintenance])
    end

    for i in 1:length(process.maintenance_times) -1
        mtn_time = process.maintenance_times[i]
        next_mtn_time = process.maintenance_times[i+1]
        between_maintenances = findall(t -> t > mtn_time && t<=next_mtn_time, process.underlying_process.times)
        if !isempty(between_maintenances)
            # Concatenate the part before last_before_maintenance into new_values
            append!(new_values, (1 - process.rho) * process.underlying_process.values[between_maintenances[1]-1])
            append!(new_values, Y[between_maintenances])
        end
    end
    
    m = findfirst(t -> t == process.maintenance_times[end], process.underlying_process.times)
    append!(new_values, (1 - process.rho) * process.underlying_process.values[m])
    append!(new_values, Y[m+1:end])

    t1 = 1
    t2 = 0
   for i in 1:process.k+1
        t2 = length(process.new_times[i]) + t2
        push!(process.values, new_values[t1:t2])
        t1 = t2 + 1
   end
end

# Méthode pour tracer le processus de Wiener avec les temps de maintenance
function plot!(process::WienerARD1)
    # Tracer le processus de Wiener
    # plot(process.underlying_process.times, process.values, xlabel="Time", ylabel="WienerARD1 Process", label="WienerARD1 Process", legend=:topright)
    for i in 1:process.k+1
        plot!(process.new_times[i], process.values[i], linestyle=:dash, markercolor=:red, color=:blue, label= i==1 ? "Processus De Wiener ARD1" : false)
    end
    # plot!(xlabel="Time", ylabel="", label="Processus De Wiener ARD1")
    # Tracer la droite mu*t
    # plot!(process.underlying_process.times, process.underlying_process.mu .* process.underlying_process.times, label="mu*t", linestyle=:dash)

    vline!(process.maintenance_times, label="Maintenance", color=:red)
end


function observations_sampling(ps::WienerARD1, nb)
    observations = Vector{Vector{Float64}}()
    times = Vector{Vector{Float64}}()
    indices = collect(1:nb:length(ps.values[1])-nb)
    push!(observations, ps.values[1][indices])
    push!(times, ps.new_times[1][indices])
    for i in 2:ps.k + 1
        # Generate a deterministic set of indices, e.g., every third element
        indices = collect(nb+1:nb:length(ps.values[i])-nb)
        push!(observations, ps.values[i][indices])
        push!(times, ps.new_times[i][indices])
    end
    return observations, times
end


function s(j::Int, rho::Float64, k::Int, delta_t::Vector{Vector{Float64}})
    if !(1 <= j <= k)
        exit()
    end
    
    if (j+1) > 2
        return delta_t[j + 1][1] + rho * rho * delta_t[j][1] + (1 - rho) * (1 - rho) * delta_t[j][end]
    else 
        return delta_t[j + 1][1] + (1 - rho) * (1 - rho) * delta_t[j][end]
    end
end

# Initialize Sigma matrix
function Sigma(rho::Float64, k::Int, delta_t::Vector{Vector{Float64}})
    
    S = zeros(k, k)

    # Populate Sigma using array comprehensions
    for i in 1:k
        S[i, i] = s(i, rho, k, delta_t)
    end

    for i in 1:(k - 1)
        S[i, i+1] = - rho * delta_t[i + 1][1]
        S[i+1, i] = - rho * delta_t[i + 1][1]
   
    end

    return S
end

function u_revised(j::Int, rho::Float64, k::Int, vect::Vector{Vector{Float64}})
    if !(1 <= j <= k)
        exit()
    end

    if (j+1) > 2
        return vect[j + 1][1] - rho * vect[j][1] + (1 - rho) * vect[j][end]
    else  
        return vect[j + 1][1] + (1 - rho) * vect[j][end]
    end
end

function v_revised(j::Int, rho::Float64, k::Int, vect::Vector{Vector{Float64}})
    
    # if j<=1 
    #     diff_values=diff(values[j][1:(end-1)])

    # else
    # diff_values = diff(values[j][2:(end-1)])
    # end
        
    result = rho * sum(diff(vect[j][1:end]))
    return result
end

function delta2(k::Int, vect::Vector{Vector{Float64}})
    differences = Vector{Vector{Float64}}()
    #differences=diff(values[1][1:(end-1)]) #si au moins 2 obs entre maint
    # Parcourir les données
    for j in 1:(k + 1)
        push!(differences, diff(vect[j][1:(end)]))
    end

    return differences
end

function delta2_obs(k::Int, observations::Vector{Vector{Float64}})
    differences=Vector{Vector{Float64}}()
    # Parcourir les données
    for j in 1:(k + 1)
        push!(differences, diff(observations[j][1:(end)])) 
    end

    return differences
end

# observations, times = observations_sampling(psARD1, 1)
# delta2_obs(psARD1.k,times)

function z_revised(k::Int, vect::Vector{Vector{Float64}})
    # Initialiser un vecteur pour stocker les différences successives
    differences = Float64[]

    # Parcourir les données
    for i in 1:k
        push!(differences, vect[i + 1][1] - vect[i][end]) # Δ! hypothèses:au - 2 obs entre 2 maintenances successives
    end

    return differences
end

# println(z(psARD1.k, psARD1.values))

function mu_chapeau_revised(rho::Float64, k::Int, observations::Vector{Vector{Float64}}, delta_t::Vector{Vector{Float64}}) 
    # observations, times = observations_sampling(psARD1, 1)
    # Calculer l'inverse de Sigma
    Sigma_inv = inv(Sigma(rho, k, delta_t))
    
    V = [v_revised(j, rho, k, observations) for j in 1:size(Sigma_inv)[1]] #/

    U = [u_revised(j, rho, k, delta_t) for j in 1:length(V)] #/
    
    Z = z_revised(k, observations)
    
    # Calculer le produit transpose(u) * Sigma_inv_v
    a = dot(U, Sigma_inv * Z)

    b = dot(U, Sigma_inv * V)
    
    c = sum(map(sum, delta2_obs(k, observations)))
    
    d = dot(U, Sigma_inv * U)

    e = sum(map(sum, delta_t))

    return (a + b + c) / (d + e)
end


function sigma2_chapeau_revised(rho::Float64, k::Int, observations::Vector{Vector{Float64}}, delta_t::Vector{Vector{Float64}})
    # observations, times = observations_sampling(psARD1, 1)
    # Calculer l'inverse de Sigma
    Sigma_inv = inv(Sigma(rho, k, delta_t))
    
    V = [v_revised(j, rho, k, observations) for j in 1:size(Sigma_inv)[1]] #/
    
    U = [u_revised(j, rho, k, delta_t) for j in 1:length(V)] #/
    
    Z = z_revised(k, observations)

    mu = mu_chapeau_revised(rho, k, observations, delta_t)

    # Calculer le produit transpose(u) * Sigma_inv_v
    a = Z - mu .* U + V

    b = dot(a, Sigma_inv * a)
    
    diffs = delta2_obs(k, observations)

    d = 0
    for (dy, dt) in zip(diffs, delta_t)
        for (dy_j, dt_j) in zip(dy, dt)
            d += ((dy_j - mu * dt_j)^2) / dt_j
        end
    end

    N = sum(length(observations[i]) for i in 1:k + 1)
    
    return (b + d) / N
end

function objectif_revised(rho::Float64, k::Int, observations::Vector{Vector{Float64}}, delta_t::Vector{Vector{Float64}}, N::Int)
    return N * log(sigma2_chapeau_revised(rho, k, observations, delta_t)) / 2 + log(sqrt(det(Sigma(rho, k, delta_t)))) 
end

function estimateur_rho_chapeau_revised(k::Int, observations::Vector{Vector{Float64}}, delta_t::Vector{Vector{Float64}})
    
    N = sum(length(observations[i]) for i in 1:k + 1)

    result = optimize(rho -> objectif_revised(rho, k, observations, delta_t, N), 0.0, 1.0)  # Minimise sur l'intervalle [0.0, 1.0]

    return Optim.minimizer(result)
end
