using DataFrames
using ExcelReaders
using Plots
using DataValues
using XLSX
using Statistics
using Tables
import Plots: plot!, vline!, plot
using Printf

mutable struct GV
    numero::Float64
    palier::String
    unite::String
    sous_unite::String
    circuit::String
    ref::String
    reg_ref::String
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

    # fonction construteur
    function GV(numero::Float64, palier::String, unite::String, sous_unite::String, circuit::String, 
                ref::String, reg_ref::String, avant_RGV::Bool, 
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

"""
Convertit une matrice en un DataFrame. La fonction prend en entrée une matrice où la première ligne contient les noms des colonnes,
et les lignes suivantes contiennent les données.

# Arguments
- `mat::Matrix{T}`: Une matrice de type `T`, où `T` peut être n'importe quel type de données supporté. La première ligne de la matrice est utilisée
  pour les noms de colonnes du DataFrame, tandis que les lignes suivantes sont les données du DataFrame.

# Returns
- `DataFrame`: Un DataFrame contenant les données de la matrice. Les noms des colonnes sont pris à partir de la première ligne de la matrice,
  et les données proviennent des lignes suivantes.
"""

function MatrixToDataFrame(mat)
    DF_mat = DataFrame(
        mat[2:end, 1:end],
        string.(mat[1, 1:end])
    )
    return DF_mat
end


"""
Convertit une matrice en deux DataFrames en fonction du circuit spécifié. La fonction extrait des colonnes spécifiques de la matrice
et crée deux DataFrames : `df_enc` pour les données d'encrassement et `df_ind_col_3` pour les données associées à la colonne `IND_COL_3`.

# Arguments
- `mat::Matrix{T}`: Une matrice de type `T`, où `T` est un type de données supporté. La matrice doit contenir au moins 3 lignes et les colonnes
  nécessaires pour extraire les données selon le circuit spécifié.
- `circuit::String`: Une chaîne de caractères indiquant le circuit à utiliser. Les valeurs acceptées sont "C1", "C2", "C3" et "C4".

# Returns
- `df_enc::DataFrame`: Un DataFrame contenant les données d'encrassement. Les colonnes sont nommées en fonction des valeurs de la matrice et du circuit.
- `df_ind_col_3::DataFrame`: Un DataFrame contenant les données associées à la colonne `IND_COL_3`. Les colonnes sont également nommées en fonction
  des valeurs de la matrice et du circuit.
"""

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
    elseif circuit == "C4"
        df_enc[!, column_names[5]] = mat[3:end,6] + 0.12 .* coalesce.(mat[3:end,26])
    end
    
    df_ind_col_3[!, column_names[1]] = mat[3:end,1]
    if circuit == "C1"
        df_ind_col_3[!, column_names[6]] = mat[3:end,15] 
    elseif circuit == "C2"
        df_ind_col_3[!, column_names[7]] = mat[3:end,16]
    elseif circuit == "C3"
        df_ind_col_3[!, column_names[8]] = mat[3:end,17]
    elseif circuit == "C4"
        df_ind_col_3[!, column_names[9]] = mat[3:end,18]
    end
    return df_enc, df_ind_col_3
end

"""
Affiche un arbre hiérarchique à partir des nœuds `NAryTreeNode` fournis, et enregistre la représentation textuelle dans un fichier spécifié.

La fonction parcourt récursivement les nœuds de l'arbre et écrit chaque niveau hiérarchique dans un fichier texte. Les niveaux sont indentés pour refléter la structure de l'arbre.

# Arguments
- `paliers::Vector{NAryTreeNode}`: Un vecteur de nœuds `NAryTreeNode` représentant les racines de l'arbre. Chaque nœud peut avoir des enfants, qui sont des instances de `NAryTreeNode`.
- `filename::String`: Le nom du fichier (sans chemin) dans lequel la représentation textuelle de l'arbre sera enregistrée. 
    Le fichier sera créé dans le sous-répertoire `results` du chemin de projet.

# Returns
- Cette fonction ne retourne rien. Elle écrit directement dans le fichier spécifié.
"""

# Fonction récursive pour afficher l'arbre à partir des paliers dans un fichier texte
function print_tree_from_paliers(paliers::Vector{NAryTreeNode}, filename::String)
    full_filename = joinpath(chemin_projet, string("results/", filename))
    open(full_filename, "w") do file
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

"""
Trouve et retourne la chaîne de caractères dans un vecteur `v` qui contient le nombre le plus élevé extrait à partir des chaînes. 
Les chaînes doivent contenir des nombres formatés comme `E<number>`, où `<number>` est un entier.

La fonction parcourt les éléments du vecteur, extrait les nombres à partir des chaînes en utilisant une expression régulière, 
et retourne la chaîne qui contient le nombre le plus élevé.

# Arguments
- `v::Vector{Union{Any, String}}`: Un vecteur contenant des éléments de type `String`. Chaque chaîne doit potentiellement contenir un nombre au format `E<number>`.
Le type Any est ajouté car les données lus des fichiers excel sont stockés avec Any comme type

# Returns
- `String`: La chaîne de caractères du vecteur qui contient le nombre le plus élevé extrait. Si aucun nombre n'est trouvé, la fonction retourne une chaîne vide.
"""

function max_string(v::Vector{Union{Any, String}})
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

"""

Cherche toutes les chaînes dans un vecteur de chaînes `vec` qui contiennent un sous-ensemble de caractères spécifié par `substring`, et retourne un vecteur des chaînes correspondantes.

La fonction utilise la fonction `occursin` pour déterminer si une chaîne contient le sous-ensemble spécifié, et retourne un vecteur avec toutes les chaînes où ce sous-ensemble apparaît.

# Arguments
- `substring::String`: La sous-chaîne à rechercher dans les chaînes du vecteur.
- `vec::Vector{String}`: Un vecteur de chaînes de caractères dans lequel rechercher.

# Returns
- `Vector{String}`: Un vecteur de chaînes contenant toutes les chaînes du vecteur d'entrée qui contiennent la sous-chaîne spécifiée.

"""


function find_in_vector(substring::String, vec::Vector{String})
    # Chercher l'occurrence dans le vecteur de strings
    indices = findall(x -> occursin(substring, x), vec)    
    
    return vec[indices]
end

"""
Convertit un nombre à virgule flottante (`Float64`) en une chaîne de caractères avec une virgule comme séparateur décimal, formatée avec une précision de 2 décimales.

La fonction utilise `@sprintf` pour formater le nombre avec 2 décimales, puis remplace le point décimal par une virgule pour se conformer aux conventions de certains formats numériques.

# Arguments
- `num::Float64`: Le nombre à virgule flottante à convertir en chaîne de caractères.

# Returns
- `String`: La représentation en chaîne de caractères du nombre, formatée avec 2 décimales et utilisant une virgule comme séparateur décimal.
"""

# Fonction pour convertir un float en string avec une virgule, formaté avec une précision de 2 décimales
function float_to_comma_string(num::Float64)::String
    # Formattage avec 2 décimales et remplacement du point par une virgule
    return replace(@sprintf("%.2f", num), "." => ",")
end

"""
Calcule le nombre de nettoyages précédents pour chaque ligne de `ind_col_1` en fonction des heures de nettoyage présentes dans le DataFrame `nettoyages`. Retourne un vecteur d'entiers représentant le nombre de nettoyages antérieurs pour chaque ligne.

La fonction compare les heures de nettoyage dans `ind_col_1` avec celles dans `nettoyages` pour déterminer combien de nettoyages ont eu lieu avant chaque nettoyage spécifié dans `ind_col_1`. Elle prend également en compte la colonne `APRES_NET` si elle existe.

# Arguments
- `ind_col_1::DataFrame`: Un DataFrame contenant une colonne `HEURES_MAT` qui représente les heures de nettoyage et éventuellement une colonne `APRES_NET` qui indique si le nettoyage est postérieur à un autre nettoyage.
- `nettoyages::DataFrame`: Un DataFrame contenant une colonne `HEURES_MAT` représentant les heures des nettoyages précédents.

# Returns
- `Vector{Int}`: Un vecteur d'entiers où chaque élément représente le nombre de nettoyages antérieurs pour chaque ligne de `ind_col_1`. La taille du vecteur est égale au nombre de lignes dans `ind_col_1`.
"""

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

"""

Trace des segments de lignes sur un graphique `p` où une condition sur les éléments du vecteur `z` est satisfaite. 
La fonction utilise les coordonnées de `x` et `y` pour les segments de ligne et applique un style de ligne en pointillés.

# Arguments
- `p`: Un objet de type `Plot` dans lequel les segments de ligne seront tracés.
- `x`: Un vecteur de coordonnées x.
- `y`: Un vecteur de coordonnées y.
- `z`: Un vecteur de conditions. Les segments de ligne seront tracés uniquement lorsque `z[i] == z[i + 1]`.
- `color`: La couleur des segments de ligne.

# Returns
- La fonction modifie l'objet `p` en ajoutant les segments de ligne qui satisfont la condition.
"""

function plot_with_condition!(p, x, y, z, color)
    for i in 1:length(x) - 1
        if z[i] == z[i + 1] 
            plot!(p, x[i:i + 1], y[i:i + 1], linestyle=:dash,
            color=color, label = false)
        end
    end
end

"""
Ajoute des éléments de tracé à plusieurs graphiques en fonction des données contenues dans un objet `GV`. 
La fonction trace des segments de lignes et des points de dispersion conditionnels, ainsi que des lignes verticales représentant des maintenances.

# Arguments
- `gv::GV`: Un objet contenant plusieurs DataFrames et informations nécessaires pour les tracés.
- `p_1_2::Plots.Plot{Plots.GRBackend}`: Le graphique principal pour les données `IND_COL_1` et `IND_COL_2`.
- `p_3::Plots.Plot{Plots.GRBackend}`: Le graphique pour les données `IND_COL_3`.
- `p_enc::Plots.Plot{Plots.GRBackend}`: Le graphique pour les données `IND_ENC`.
"""

function plot!(gv::GV, p_1_2::Plots.Plot{Plots.GRBackend}, p_3::Plots.Plot{Plots.GRBackend}, p_enc::Plots.Plot{Plots.GRBackend})
    if !isempty(gv.IND_COL_1)
        plot_with_condition!(p_1_2, gv.IND_COL_1.HEURES_MAT, gv.IND_COL_1.VALEUR_CHAUD, 
        gv.IND_COL_1.nb_nettoyages_precedents, :yellow)
        scatter!(p_1_2, gv.IND_COL_1.HEURES_MAT, gv.IND_COL_1.VALEUR_CHAUD, alpha=.75, 
        label = string("1-C-", gv.circuit), markershape=circuit_shapes[gv.circuit], markercolor=:yellow, 
        markerstrokewidth = 0.5, markersize=6, legend=:topleft)
        
        plot_with_condition!(p_1_2, gv.IND_COL_1.HEURES_MAT, gv.IND_COL_1.VALEUR_FROID, 
        gv.IND_COL_1.nb_nettoyages_precedents, :green)
        scatter!(p_1_2, gv.IND_COL_1.HEURES_MAT, gv.IND_COL_1.VALEUR_FROID, alpha=.75, 
        label = string("1-F-", gv.circuit), markershape=circuit_shapes[gv.circuit], markercolor=:green, 
        markerstrokewidth = 0.5)
    end
    
    if !isempty(gv.IND_COL_2)
        plot_with_condition!(p_1_2, gv.IND_COL_2.HEURES_MAT, gv.IND_COL_2.VALEUR_CHAUD, 
        gv.IND_COL_2.nb_nettoyages_precedents, :red)
        scatter!(p_1_2, gv.IND_COL_2.HEURES_MAT, gv.IND_COL_2.VALEUR_CHAUD, 
        alpha=.75, label = string("2-C-", gv.circuit), markershape=circuit_shapes[gv.circuit], markercolor=:red, 
        markerstrokewidth = 0.5)

        plot_with_condition!(p_1_2, gv.IND_COL_2.HEURES_MAT, gv.IND_COL_2.VALEUR_FROID, 
        gv.IND_COL_2.nb_nettoyages_precedents, :blue)
        scatter!(p_1_2, gv.IND_COL_2.HEURES_MAT, gv.IND_COL_2.VALEUR_FROID, alpha=.75, 
        label = string("2-F-", gv.circuit), markershape=circuit_shapes[gv.circuit], markercolor=:blue, 
        markerstrokewidth = 0.5)
    end

    if !isempty(gv.IND_COL_3)
        plot_with_condition!(p_3, gv.IND_COL_3.HEURES_MAT, gv.IND_COL_3[:, 2], 
        gv.IND_COL_3.nb_nettoyages_precedents, circuit_enc_colors[gv.circuit])
        scatter!(p_3, gv.IND_COL_3.HEURES_MAT, gv.IND_COL_3[:, 2], 
        alpha=.75, label = gv.circuit, markershape=circuit_shapes[gv.circuit],
        markercolor=circuit_enc_colors[gv.circuit], markerstrokewidth = 0.5)
    end

    if !isempty(gv.IND_ENC)
        plot_with_condition!(p_enc, gv.IND_ENC.HEURES_MAT, gv.IND_ENC[:, 2], 
        gv.IND_ENC.nb_nettoyages_precedents, circuit_enc_colors[gv.circuit])
        scatter!(p_enc, gv.IND_ENC.HEURES_MAT, gv.IND_ENC[:, 2], 
        alpha=.75, label = gv.circuit, markershape=circuit_shapes[gv.circuit], 
        markercolor=circuit_enc_colors[gv.circuit], markerstrokewidth = 0.5)
    end
    
    if !isempty(gv.maintenances)
        cur = gv.circuit== "C1" ? true : false
        prev = gv.circuit== "C1" ? true : false
        for i in 1:length(gv.maintenances.HEURES_MAT)
            linestyle = gv.maintenances[i, 2] == 1 ? :dot : :dash
            label = gv.maintenances[i, 2] == 1 ? "curatif" : "preventif"
            label = cur && label=="curatif" ? label : (prev ? label : false)
            vline!(p_1_2, [gv.maintenances[i, 1]], color=:black, linestyle=linestyle, label=label)
            vline!(p_3, [gv.maintenances[i, 1]], color=:black, linestyle=linestyle, label=label)
            vline!(p_enc, [gv.maintenances[i, 1]], color=:black, linestyle=linestyle, label=label)
            cur = label == "curatif" ? false : cur
            prev = label == "preventif" ? false : prev
        end
    end
end

"""
Trace et enregistre des graphiques pour des sous-unités d'une unité, en utilisant des données avant et après une date de maintenance spécifique (RGV).

# Arguments
- `sous_unite::NAryTreeNode`: Un nœud représentant une sous-unité dans une structure d'arbre N-aire. Chaque sous-unité contient des états enfants ("avant_RGV" et "apres_RGV"), 
et chaque état contient des circuits avec leurs données associées.

# Description
La fonction :
1. Crée des graphiques pour les données avant et après la date de maintenance (RGV).
2. Trace des segments de ligne et des points de dispersion pour les valeurs de différentes colonnes (`IND_COL_1`, `IND_COL_2`, `IND_COL_3`, `IND_ENC`), 
en différenciant les circuits et les états.
3. Ajoute des lignes verticales représentant la date de maintenance (RGV) sur les graphiques.
4. Ajuste les limites des axes pour inclure toutes les données pertinentes.
5. Enregistre le graphique final combiné dans un fichier PNG.
"""

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
end

# Fonction pour obtenir REFERENCE2 associé à REFERENCE
function get_REF2(ref, df_carac)
    row = df_carac[df_carac.REFERENCE .== ref, :]
    if nrow(row) == 0
        return nothing  # ou vous pouvez choisir de lever une erreur, ex: error("Element not found")
    else
        return row.REFERENCE2[1]
    end
end


"""
Crée et initialise un dictionnaire global `GVs_dict` associant des numéros de GV à des objets `GV` contenant ses informations détaillées

# Arguments
- `paliers::Vector{NAryTreeNode}`: Un vecteur de nœuds représentant les paliers dans une structure d'arbre N-aire. 

# Description
La fonction :
1. Parcourt les paliers, unités, sous-unités et circuits pour récupérer et traiter les données associées.
2. Filtre et organise les données en fonction des états avant et après RGV.
3. Calcule des valeurs spécifiques telles que `PE_max`, `ylim_IND_COL`, et `date_max`.
4. Crée des objets `GV` pour chaque numéro de GV (du fichier HEURES.xls) avec les informations consolidées.
5. Ajoute ces objets `GV` au dictionnaire `GVs_dict`.
6. Met à jour la structure d'arbre pour inclure les numéros de GV en tant qu'enfants des circuits.
"""

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
                                    
                                    dropmissing!(df_enc)
                                    dropmissing!(df_ind_col_3)
                                    df_enc.nb_nettoyages_precedents = count_previous_cleanings(df_enc, nettoyages)
                                    df_ind_col_3.nb_nettoyages_precedents = count_previous_cleanings(df_ind_col_3, nettoyages)

                                    date_max = max(date_max, maximum(df_enc.HEURES_MAT))
                                end
                                
                            end
                            

                            date_max = max(date_max, maximum(filter(row -> row.UNITE .== unite.value && row.SOUS_UNITE .== sous_unite.value, df_Infos_gen).HEURES_MAT))

                            gv = GV(num, palier.value, unite.value, sous_unite.value, circuit.value, ref, get_REF2(ref, df_carac), 
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