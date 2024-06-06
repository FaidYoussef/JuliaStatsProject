# JuliaStatsProject

Ce projet utilise Julia pour analyser des données statistiques provenant de fichiers Excel (.xls) ainsi que des données simulées. Les résultats sont visualisés sous forme de graphiques et exportés pour une analyse ultérieure.

## Structure du projet

- `data/`: Contient les données brutes et traitées.
- `notebooks/`: Notebooks Jupyter pour l'analyse interactive.
- `src/`: Scripts Julia pour le traitement, la simulation et la visualisation des données.
- `plots/`: Graphiques générés.
- `results/`: Résultats finaux des analyses.
- `README.md`: Description du projet.
- `Project.toml`: Configuration du projet Julia.

## Instructions

1. Cloner le dépôt.
2. Installer les dépendances avec `Pkg.instantiate()`.
3. Exécuter les scripts dans le répertoire `src/` pour traiter, simuler et visualiser les données.
4. Utiliser les notebooks Jupyter pour des analyses interactives.

## Dépendances

- Julia 1.8+
- Paquets: DataFrames, CSV, XLSX, Plots, etc.
