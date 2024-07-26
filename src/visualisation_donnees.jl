using DataFrames
using ExcelReaders
using Plots
using DataValues
using XLSX
using Statistics
using Tables
import Plots: plot!, vline!, plot
using Printf

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
        titlefont=10,
        xguidefont = font(8),
        yguidefont = font(8)
        )
    p_3_avant = plot(
        ylabel="IND-COL-3",  
        titlefont=10,
        xguidefont = font(8),
        yguidefont = font(8)
        )
    p_enc_avant = plot(
        xlabel="HEURES_MAT", 
        ylabel="IND-ENC",  
        titlefont=10,
        xguidefont = font(8),
        yguidefont = font(8)
        )
    p_1_2_apres = plot(
        ylabel="IND-COL",  
        titlefont=10,
        xguidefont = font(8),
        yguidefont = font(8)
        )
    p_3_apres = plot(
        ylabel="IND-COL-3",  
        titlefont=10,
        xguidefont = font(8),
        yguidefont = font(8)
        )
    p_enc_apres = plot(
        xlabel="HEURES_MAT", 
        ylabel="IND-ENC",  
        titlefont=10,
        xguidefont = font(8),
        yguidefont = font(8)
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

    ylims!(p_1_2_avant, 0, ylim_IND_COL*101/100)
    ylims!(p_1_2_apres, 0, ylim_IND_COL*101/100)

    xlims!(p_1_2_avant, 0, date_max*101/100)
    xlims!(p_3_avant, 0, date_max*101/100)
    xlims!(p_enc_avant, 0, date_max*101/100)

    xlims!(p_1_2_apres, 0, date_max*101/100)
    xlims!(p_3_apres, 0, date_max*101/100)
    xlims!(p_enc_apres, 0, date_max*101/100)

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

    p = plot(p_1_2_avant, p_1_2_apres, p_3_avant, p_3_apres, p_enc_avant, p_enc_apres, layout=(3, 2), size=(1000, 800))

    # Chemin du répertoire où vous souhaitez enregistrer le fichier (relatif au répertoire de travail actuel)
    directory = string(chemin_projet, "plots/Visualisation")
            
    # Combiner le chemin de répertoire et le nom du fichier
    filename = joinpath(directory, string("$unite", " ", "$sous_unite.png"))
    savefig(p, filename)
end