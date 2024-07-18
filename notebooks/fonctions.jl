using DataFrames
using ExcelReaders
using Plots
using DataValues
using XLSX
using Statistics
using Tables
import Plots: plot!, vline!, plot

mutable struct GV
    numero::Float64
    palier::String
    unite::String
    sous_unite::String
    circuit::String
    ref::String
    reg_ref::Vector{String}
    avant_RGV::Bool
    numero_suc_ou_pred::Union{Float64, Missing}
    maintenances::DataFrame
    IND_COL_1::DataFrame
    PE_max_IND_COL_1::String
    IND_COL_2::DataFrame
    IND_COL_3::DataFrame
    IND_ENC::DataFrame
    date_max::Float64
    date_RGV::Union{Float64, Missing}
    ylim_IND_COL::Union{Float64, Int}
    pb::Bool

    function GV(numero::Float64, palier::String, unite::String, sous_unite::String, circuit::String, 
                ref::String, reg_ref::Vector{String}, avant_RGV::Bool, 
                numero_suc_ou_pred::Union{Float64, Missing}, maintenances::DataFrame, 
                IND_COL_1::DataFrame, PE_max_IND_COL_1::String, IND_COL_2::DataFrame, 
                IND_COL_3::DataFrame, IND_ENC::DataFrame, date_max::Float64, date_RGV::Union{Float64, Missing}, 
                ylim_IND_COL::Union{Float64, Int})
        new(numero, palier, unite, sous_unite, circuit, ref, reg_ref, avant_RGV, numero_suc_ou_pred, 
        maintenances, IND_COL_1, PE_max_IND_COL_1, IND_COL_2, IND_COL_3, IND_ENC, date_max, date_RGV,
        ylim_IND_COL)
    end
end

mutable struct NAryTreeNode
    parent::Union{NAryTreeNode, Missing}
    value::Union{String, Float64, Missing}
    children::Vector{NAryTreeNode}

    function NAryTreeNode(parent::Union{NAryTreeNode, Missing}, value::Union{String, Float64, Missing}, children::Vector{NAryTreeNode})
        new(parent, value, children)
    end
end

function MatrixToDataFrame(mat)
    DF_mat = DataFrame(
        mat[2:end, 1:end],
        string.(mat[1, 1:end])
    )
    return DF_mat
end

function IND_COL_3_and_EncMatToDataFrame(mat, circuit::String)
    # Extraire les noms des colonnes
    column_names = [mat[1,1],"$(mat[2,3])_ENC", "$(mat[2,4])_ENC", "$(mat[2,5])_ENC", "$(mat[2,6])_ENC", "$(mat[2,15])_IND_COL_3", "$(mat[2,16])_IND_COL_3", "$(mat[2,17])_IND_COL_3", "$(mat[2,18])_IND_COL_3"]

    # Créer un DataFrame à partir des données extraites
    df_enc = DataFrame()
    df_ind_col_3 = DataFrame()

    # Ajouter les données au DataFrame
    df_enc[!, column_names[1]] = mat[3:end,1]

    if circuit == "C1"
        df_enc[!, column_names[2]] = mat[3:end,3] + 0.12 .* coalesce.(mat[3:end,23])
    elseif circuit == "C2"
        df_enc[!, column_names[3]] = mat[3:end,4] + 0.12 .* coalesce.(mat[3:end,24])
    elseif circuit == "C3"
        df_enc[!, column_names[4]] = mat[3:end,5] + 0.12 .* coalesce.(mat[3:end,25])
    else
        df_enc[!, column_names[5]] = mat[3:end,6] + 0.12 .* coalesce.(mat[3:end,26])
    end
    
    df_ind_col_3[!, column_names[1]] = mat[3:end,1]
    if circuit == "C1"
        df_ind_col_3[!, column_names[6]] = mat[3:end,15] 
    elseif circuit == "C2"
        df_ind_col_3[!, column_names[7]] = mat[3:end,16]
    elseif circuit == "C3"
        df_ind_col_3[!, column_names[8]] = mat[3:end,17]
    else
        df_ind_col_3[!, column_names[9]] = mat[3:end,18]
    end
    return df_enc, df_ind_col_3
end



# Fonction récursive pour afficher l'arbre à partir des paliers dans un fichier texte
function print_tree_from_paliers(paliers::Vector{NAryTreeNode}, filename::String)
    open(filename, "w") do file
        for palier in paliers
            write(file, "Palier: ", string(palier.value), "\n")
            for unite in palier.children
                write(file, "   |- Unité: ", string(unite.value), "\n")
                for sous_unite in unite.children
                    write(file, "       |- Sous-unité: ", string(sous_unite.value), "\n")
                    for etat in sous_unite.children
                        write(file, "           |- ", string(etat.value), "\n")
                        for circuit in etat.children
                            write(file, "               |- ", string(circuit.value), "\n")
                            for num in circuit.children
                                if !ismissing(num)
                                    write(file, "                 |- ", string(num.value), "\n")
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function max_string(v::Vector{Any})
    # Extract numbers from the strings and find the maximum
    max_str = ""
    max_num = -Inf
    for s in v
        # Use a regular expression to extract the number
        m = match(r"E(\d+)", s)
        if m !== nothing
            num = parse(Int, m.captures[1])
            if num > max_num
                max_num = num
                max_str = s
            end
        end
    end
    return max_str
end

using Printf

function find_in_vector(substring::String, vec::Vector{String})
    # Chercher l'occurrence dans le vecteur de strings
    indices = findall(x -> occursin(substring, x), vec)    
    
    return vec[indices]
end

# Fonction pour convertir un float en string avec une virgule, formaté avec une précision de 2 décimales
function float_to_comma_string(num::Float64)::String
    # Formattage avec 2 décimales et remplacement du point par une virgule
    return replace(@sprintf("%.2f", num), "." => ",")
end




# Fonction pour calculer le nombre de nettoyages précédents pour chaque ligne de ind_col_1
function count_previous_cleanings(ind_col_1::DataFrame, nettoyages::DataFrame)::Vector{Int}
    if isempty(nettoyages)
        return zeros(Int8, nrow(ind_col_1))
    end
    counts = Vector{Int}(undef, nrow(ind_col_1))
    if "APRES_NET" in names(ind_col_1)
        for i in 1:nrow(ind_col_1)
            counts[i] = sum(nettoyages.HEURES_MAT .< ind_col_1.HEURES_MAT[i]) + (ind_col_1.APRES_NET[i] ? 1 : 0)
        end
    else
        for i in 1:nrow(ind_col_1)
            counts[i] = sum(nettoyages.HEURES_MAT .< ind_col_1.HEURES_MAT[i]) 
        end
    end

    return counts
end



function plot_with_condition!(p, x, y, z, color)
    for i in 1:length(x) - 1
        if z[i] == z[i + 1] 
            plot!(p, x[i:i + 1], y[i:i + 1], linestyle=:dash,
            color=color, legend = false)
        end
    end
end

function plot!(gv::GV, p_1_2::Plots.Plot{Plots.GRBackend}, p_3::Plots.Plot{Plots.GRBackend}, p_enc::Plots.Plot{Plots.GRBackend})
    if !isempty(gv.IND_COL_1)
        # plot!(p_1_2, gv.IND_COL_1.HEURES_MAT, gv.IND_COL_1.VALEUR_CHAUD, linestyle=:dash,
        # color=:yellow, legend = false)
        plot_with_condition!(p_1_2, gv.IND_COL_1.HEURES_MAT, gv.IND_COL_1.VALEUR_CHAUD, 
        gv.IND_COL_1.nb_nettoyages_precedents, :yellow)
        scatter!(p_1_2, gv.IND_COL_1.HEURES_MAT, gv.IND_COL_1.VALEUR_CHAUD, alpha=.75, 
        label = false, markershape=circuit_shapes[gv.circuit], markercolor=:yellow, 
        legend = false, markerstrokewidth = 0.5, markersize=6)
        
        # plot!(p_1_2, gv.IND_COL_1.HEURES_MAT, gv.IND_COL_1.VALEUR_FROID, linestyle=:dash,
        # color=:green, legend = false)
        plot_with_condition!(p_1_2, gv.IND_COL_1.HEURES_MAT, gv.IND_COL_1.VALEUR_FROID, 
        gv.IND_COL_1.nb_nettoyages_precedents, :green)
        scatter!(p_1_2, gv.IND_COL_1.HEURES_MAT, gv.IND_COL_1.VALEUR_FROID, alpha=.75, 
        label = false, markershape=circuit_shapes[gv.circuit], markercolor=:green, 
        legend = false, markerstrokewidth = 0.5)
    end
    
    if !isempty(gv.IND_COL_2)
        # plot!(p_1_2, gv.IND_COL_2.HEURES_MAT, gv.IND_COL_2.VALEUR_CHAUD, linestyle=:dash,
        # color=:red, legend = false)
        plot_with_condition!(p_1_2, gv.IND_COL_2.HEURES_MAT, gv.IND_COL_2.VALEUR_CHAUD, 
        gv.IND_COL_2.nb_nettoyages_precedents, :red)
        scatter!(p_1_2, gv.IND_COL_2.HEURES_MAT, gv.IND_COL_2.VALEUR_CHAUD, 
        alpha=.75, label = false, markershape=circuit_shapes[gv.circuit], markercolor=:red, 
        legend = false, markerstrokewidth = 0.5)

        # plot!(p_1_2, gv.IND_COL_2.HEURES_MAT, gv.IND_COL_2.VALEUR_FROID, linestyle=:dash,
        # color=:blue)
        plot_with_condition!(p_1_2, gv.IND_COL_2.HEURES_MAT, gv.IND_COL_2.VALEUR_FROID, 
        gv.IND_COL_2.nb_nettoyages_precedents, :blue)
        scatter!(p_1_2, gv.IND_COL_2.HEURES_MAT, gv.IND_COL_2.VALEUR_FROID, alpha=.75, 
        label = false, markershape=circuit_shapes[gv.circuit], markercolor=:blue, 
        legend = false, markerstrokewidth = 0.5)
    end

    if !isempty(gv.IND_COL_3)
        # plot!(p_3, gv.IND_COL_3.HEURES_MAT, gv.IND_COL_3[:, 2],
        # color= circuit_enc_colors[gv.circuit], label = false, linestyle=:dash)
        plot_with_condition!(p_3, gv.IND_COL_3.HEURES_MAT, gv.IND_COL_3[:, 2], 
        gv.IND_COL_3.nb_nettoyages_precedents, circuit_enc_colors[gv.circuit])
        scatter!(p_3, gv.IND_COL_3.HEURES_MAT, gv.IND_COL_3[:, 2], 
        alpha=.75, label = gv.circuit, markershape=circuit_shapes[gv.circuit],
        markercolor=circuit_enc_colors[gv.circuit], markerstrokewidth = 0.5)
    end

    if !isempty(gv.IND_ENC)
        # plot!(p_enc, gv.IND_ENC.HEURES_MAT, gv.IND_ENC[:, 2],
        # color= circuit_enc_colors[gv.circuit], label = false, linestyle=:dash)
        plot_with_condition!(p_enc, gv.IND_ENC.HEURES_MAT, gv.IND_ENC[:, 2], 
        gv.IND_ENC.nb_nettoyages_precedents, circuit_enc_colors[gv.circuit])
        scatter!(p_enc, gv.IND_ENC.HEURES_MAT, gv.IND_ENC[:, 2], 
        alpha=.75, label = gv.circuit, markershape=circuit_shapes[gv.circuit], 
        markercolor=circuit_enc_colors[gv.circuit], markerstrokewidth = 0.5)
    end
    
    if !isempty(gv.maintenances)
        for i in 1:length(gv.maintenances.HEURES_MAT)
            linestyle = gv.maintenances[i, 2] == 1 ? :dot : :dash
            vline!(p_1_2, [gv.maintenances[i, 1]], color=:black, linestyle=linestyle, label=false)
            vline!(p_3, [gv.maintenances[i, 1]], color=:black, linestyle=linestyle, label=false)
            vline!(p_enc, [gv.maintenances[i, 1]], color=:black, linestyle=linestyle, label=false)
        end
    end
end

function plot(sous_unite::NAryTreeNode)
    p_1_2_avant = plot(
        ylabel="IND-COL",  
        titlefont=10
        )
    p_3_avant = plot(
        ylabel="IND-COL-3",  
        titlefont=10
        )
    p_enc_avant = plot(
        xlabel="HEURES_MAT", 
        ylabel="IND-ENC",  
        titlefont=10
        )
    p_1_2_apres = plot(
        ylabel="IND-COL",  
        titlefont=10
        )
    p_3_apres = plot(
        ylabel="IND-COL-3",  
        titlefont=10
        )
    p_enc_apres = plot(
        xlabel="HEURES_MAT", 
        ylabel="IND-ENC",  
        titlefont=10,
        )
    titre_avant = ""
    titre_apres = ""
    date_RGV = missing
    ylim_IND_COL = 0
    date_max = 0
    for etat in sous_unite.children
        for circuit in etat.children
            if !ismissing(first(circuit.children))
                numero = first(circuit.children).value
                gv = GVs_dict[numero]
                circuit = gv.circuit
                PE = gv.PE_max_IND_COL_1

                if etat.value=="avant_RGV" 
                    plot!(gv, p_1_2_avant, p_3_avant, p_enc_avant)
                    titre_avant = string(titre_avant, "$circuit-$numero-$PE ") 
                    date_RGV = gv.date_RGV
                else
                    plot!(gv, p_1_2_apres, p_3_apres, p_enc_apres)
                    titre_apres = string(titre_apres, "$circuit-$numero-$PE ")
                end

                ylim_IND_COL = max(ylim_IND_COL, gv.ylim_IND_COL)
                date_max = max(date_max, gv.date_max)
            end
        end
    end

    if !ismissing(date_RGV)
        vline!(p_1_2_avant, [date_RGV], color=:black, linestyle=:solid, label="RGV")
        vline!(p_3_avant, [date_RGV], color=:black, linestyle=:solid, label="RGV")
        vline!(p_enc_avant, [date_RGV], color=:black, linestyle=:solid, label="RGV")
    else
        vline!(p_1_2_avant, [0], color=:black, label = false)
        vline!(p_3_avant, [0], color=:black, label = false)
        vline!(p_enc_avant, [0], color=:black, label = false)
    end

    ylims!(p_1_2_avant, 0, ylim_IND_COL*11/10)
    ylims!(p_1_2_apres, 0, ylim_IND_COL*11/10)

    xlims!(p_1_2_avant, 0, date_max*11/10)
    xlims!(p_3_avant, 0, date_max*11/10)
    xlims!(p_enc_avant, 0, date_max*11/10)

    xlims!(p_1_2_apres, 0, date_max*11/10)
    xlims!(p_3_apres, 0, date_max*11/10)
    xlims!(p_enc_apres, 0, date_max*11/10)

    unite = sous_unite.parent.value
    sous_unite = sous_unite.value
    titre_avant = string("$unite-$sous_unite ", titre_avant)
    titre_apres = string("$unite-$sous_unite ", titre_apres)

    title!(p_1_2_avant, titre_avant)
    title!(p_1_2_apres, titre_apres)
    title!(p_3_avant, titre_avant)
    title!(p_enc_avant, titre_avant)
    title!(p_3_apres, titre_apres)
    title!(p_enc_apres, titre_apres)

    p = plot(p_1_2_avant, p_1_2_apres, p_3_avant, p_3_apres, p_enc_avant, p_enc_apres, layout=(3, 2), size=(1800, 1200))

    # Chemin du répertoire où vous souhaitez enregistrer le fichier (relatif au répertoire de travail actuel)
    directory = string(chemin_projet, "plots/Visualisation")
            
    # Combiner le chemin de répertoire et le nom du fichier
    filename = joinpath(directory, string("$unite", " ", "$sous_unite.png"))
    savefig(p, filename)
    # display(p_1_2_avant)
    # display(p_1_2_apres)
    # display(p_3_avant)
    # display(p_3_apres)
    # display(p_enc_avant)
    # display(p_enc_apres)
end


function set_GVs_dict(paliers)
    GVs_dict = Dict{Float64, GV}()

    for palier in paliers
        unites = palier.children
        for unite in unites
            sous_unites = unite.children
            for sous_unite in sous_unites
                data_sous_unite = filter(row -> row.UNITE .== unite.value && row.SOUS_UNITE .== sous_unite.value,
                                    df_Infos_gen)
                dict = Dict{String, DataFrame}()
                dict["avant_RGV"] = data_sous_unite[data_sous_unite[:, 10] .== "ORIGINE", :]
                dict["apres_RGV"] = data_sous_unite[data_sous_unite[:, 10] .== "Remplacement", :]
                date_RGV = missing
                if !isempty(dict["apres_RGV"])
                    date_RGV = maximum(dict["avant_RGV"].HEURES_MAT)
                end
                for etat in sous_unite.children
                    ss_unite_data = filter(row -> row.UNITE .== unite.value 
                                            && row.SOUS_UNITE .== sous_unite.value
                                            && row.NUMERO in dict[etat.value].NUMERO, df1)
                    PE_max = max_string(ss_unite_data.PE)
                    ylim_IND_COL = !isempty(ss_unite_data[ss_unite_data.PE .== PE_max, :]) ? maximum(ss_unite_data[ss_unite_data.PE .== PE_max, :].VALEUR) : 0
                    for circuit in etat.children
                        num = unique(dict[etat.value][dict[etat.value].CIRCUIT .== circuit.value, :].NUMERO)
                        if length(num) == 1
                            num = num[1]
                            
                            ref = unique(dict[etat.value][dict[etat.value].CIRCUIT .== circuit.value, :].REFERENCE)[1]
                            
                            reg_ref = Vector([""])
                            
                            numero_suc_ou_pred = missing
                            if etat.value=="avant_RGV" && !isempty(dict["apres_RGV"])
                                numero_suc_ou_pred = unique(dict["apres_RGV"][dict["apres_RGV"].CIRCUIT .== circuit.value, :].NUMERO)[1]
                            end
                            if etat.value=="apres_RGV" && !isempty(dict["avant_RGV"])
                                numero_suc_ou_pred = unique(dict["avant_RGV"][dict["avant_RGV"].CIRCUIT .== circuit.value, :].NUMERO)[1]
                            end
                            
                            nettoyages = DataFrame()
                            ind_col_1 = DataFrame()
                            ind_col_2 = DataFrame()
                            df_enc, df_ind_col_3 = DataFrame(), DataFrame()
                            date_max = 0
                            if !ismissing(num)
                                nettoyages = df_nettoyages[df_nettoyages.NUMERO .== num, :]
                                nettoyages = nettoyages[:, [6, 7]] # 7 pour curatif
                                
                                ind_col_1 = df1[df1.NUMERO .== num, :]
                                if !isempty(ind_col_1)
                                    PE_max = max_string(ind_col_1.PE)
                                end
                                ind_col_1 = ind_col_1[ind_col_1.PE .== PE_max, :]

                                select!(ind_col_1, Not([:ACIERISTE, :TUBISTE, :CONSTITUTION]))
                                ind_col_1_C = ind_col_1[ind_col_1.BR .== "C", :]
                                ind_col_1_F = ind_col_1[ind_col_1.BR .== "F", :]

                                if !isempty(ind_col_1_C) || !isempty(ind_col_1_F)
                                    date_max = maximum(ind_col_1.HEURES_MAT)

                                    # Supprimer la colonne 'B'
                                    select!(ind_col_1_C, Not(:BR))
                                    select!(ind_col_1_F, Not(:BR))

                                    rename!(ind_col_1_C, :VALEUR => :VALEUR_CHAUD)
                                    rename!(ind_col_1_F, :VALEUR => :VALEUR_FROID)

                                    ind_col_1_C.nb_nettoyages_precedents = count_previous_cleanings(ind_col_1_C, nettoyages)
                                    ind_col_1_F.nb_nettoyages_precedents = count_previous_cleanings(ind_col_1_F, nettoyages)

                                    
                                    ind_col_1 = innerjoin(ind_col_1_C, ind_col_1_F, 
                                    on = [:UNITE, :SOUS_UNITE, :CIRCUIT, :NUMERO, :HEURES_MAT, :PE, :REFERENCE,
                                    :nb_nettoyages_precedents], 
                                    makeunique = true)

                                    # Ajouter une colonne pour la moyenne
                                    ind_col_1[!, :VALEUR_MOYENNE] = [mean(skipmissing([row[:VALEUR_CHAUD], row[:VALEUR_FROID]])) for row in eachrow(ind_col_1)]
                                end
                                
                                ind_col_2 = df2[df2.NUMERO .== num, :]
                                if PE_max == ""
                                    ss_unite_data = filter(row -> row.UNITE .== unite.value 
                                                && row.SOUS_UNITE .== sous_unite.value
                                                && row.NUMERO in dict[etat.value].NUMERO, df2)
                                    PE_max = max_string(ss_unite_data.PE)
                                end
                                ind_col_2 = ind_col_2[ind_col_2.PE .== PE_max, :]
                                select!(ind_col_2, Not([:ACIERISTE, :TUBISTE, :CONSTITUTION]))
                                ind_col_2_C = ind_col_2[ind_col_2.BR .== "C", :]
                                ind_col_2_F = ind_col_2[ind_col_2.BR .== "F", :]
                                
                                if !isempty(ind_col_2)
                                    date_max = max(date_max, !isempty(ind_col_2.HEURES_MAT) ? maximum(ind_col_2.HEURES_MAT) : 0)
                                    
                                    # Supprimer la colonne 'B'
                                    select!(ind_col_2_C, Not(:BR))
                                    select!(ind_col_2_F, Not(:BR))
                                    
                                    rename!(ind_col_2_C, :VALEUR => :VALEUR_CHAUD)
                                    rename!(ind_col_2_F, :VALEUR => :VALEUR_FROID)
                                    
                                    ind_col_2_C.nb_nettoyages_precedents = count_previous_cleanings(ind_col_2_C, nettoyages)
                                    ind_col_2_F.nb_nettoyages_precedents = count_previous_cleanings(ind_col_2_F, nettoyages)
                                    
                                    
                                    ind_col_2 = innerjoin(ind_col_2_C, ind_col_2_F, 
                                    on = [:UNITE, :SOUS_UNITE, :CIRCUIT, :NUMERO, :HEURES_MAT, :PE, :REFERENCE,
                                    :nb_nettoyages_precedents], 
                                    makeunique = true)
                                    # Ajouter une colonne pour la moyenne
                                    ind_col_2[!, :VALEUR_MOYENNE] = [mean(skipmissing([row[:VALEUR_CHAUD], row[:VALEUR_FROID]])) for row in eachrow(ind_col_2)]
                                    ylim_IND_COL = max(ylim_IND_COL, 
                                            !isempty(ind_col_2.VALEUR_CHAUD) ? maximum(ind_col_2.VALEUR_CHAUD) : 0, 
                                            !isempty(ind_col_2.VALEUR_FROID) ? maximum(ind_col_2.VALEUR_FROID) : 0)
                                end
                                
                                enc_files = find_in_vector(float_to_comma_string(num), xlsx_files)
                                if !isempty(enc_files)
                                    enc_file = enc_files[1]
                                    df_enc, df_ind_col_3 = IND_COL_3_and_EncMatToDataFrame(XLSX.readdata(string(directory, "$enc_file"), 
                                    "Feuil1", "A1:Z1000"), circuit.value)
                                    
                                    # df_enc, df_ind_col_3 = dropmissing(df_enc, :HEURES_MAT), dropmissing(df_ind_col_3, :HEURES_MAT)
                                    dropmissing!(df_enc)
                                    dropmissing!(df_ind_col_3)
                                    # println("*******************iiiiiiiiiiiiccccccccccccccciiiiiiiiiiiiii************")
                                    # println(df_enc[:, 2])
                                    df_enc.nb_nettoyages_precedents = count_previous_cleanings(df_enc, nettoyages)
                                    df_ind_col_3.nb_nettoyages_precedents = count_previous_cleanings(df_ind_col_3, nettoyages)

                                    date_max = max(date_max, maximum(df_enc.HEURES_MAT))
                                end
                                
                            end
                            
                            # date_max = Int(floor(date_max))
                            date_max = max(date_max, maximum(filter(row -> row.UNITE .== unite.value && row.SOUS_UNITE .== sous_unite.value, df_Infos_gen).HEURES_MAT))
                            # date_max = Int(floor(date_max))

                            gv = GV(num, palier.value, unite.value, sous_unite.value, circuit.value, ref, reg_ref, 
                            etat.value=="avant_RGV", numero_suc_ou_pred, nettoyages, ind_col_1, PE_max, 
                            ind_col_2, df_ind_col_3, df_enc, date_max, date_RGV, ylim_IND_COL)
                            GVs_dict[num] = gv
                            push!(circuit.children, NAryTreeNode(circuit, num, Vector{NAryTreeNode}()))
                        else
                            num = missing
                            push!(circuit.children, NAryTreeNode(circuit, num, Vector{NAryTreeNode}()))
                        end
                        
                    end
                end
            end
        end
    end
    return GVs_dict
end