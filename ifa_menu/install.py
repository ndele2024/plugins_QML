"""
Installe le plugin QField « IFA 2.0 — Menu ».

Trois modes, selon la façon dont vous voulez distribuer le plugin.

1) Plugin d'application (recommandé pour développer)
   Copie le dossier dans le répertoire des plugins de QField. Le plugin est
   alors actif quel que soit le projet ouvert, et il suffit de relancer QField
   (ou de désactiver/réactiver le plugin dans les réglages) pour voir les
   modifications.

       python install.py
       python install.py --app

2) Plugin de projet
   Copie tous les fichiers .qml à côté d'un projet QGIS et crée le fichier
   <nom_du_projet>.qml attendu par QField. Utile pour livrer le plugin avec un
   projet précis via QFieldCloud.

       python install.py --projet "C:\\...\\cloud_projects\\admin\\<uuid>"

3) Archive distribuable
   Produit un .zip installable depuis QField (Réglages > Plugins > installer
   depuis une URL) ou via pluginManager.installFromUrl().

       python install.py --zip

Options communes :
    --dest DIR     force le répertoire des plugins de QField (mode --app)
    --nom NOM      nom du sous-dossier / du zip (défaut : ifa_menu)
"""

from __future__ import annotations

import argparse
import platform
import shutil
import sys
import zipfile
from pathlib import Path

DOSSIER_SOURCE = Path(__file__).parent
NOM_PAR_DEFAUT = "ifa_menu"

# Fichiers embarqués dans le plugin. Tout le reste (scripts, documentation)
# reste hors de l'installation.
EXTENSIONS = (".qml", ".svg", ".txt")


def fichiers_du_plugin() -> list[Path]:
    """Fichiers à installer, triés pour un affichage stable."""
    return sorted(
        p
        for p in DOSSIER_SOURCE.iterdir()
        if p.is_file() and p.suffix.lower() in EXTENSIONS
    )


def dossier_plugins_qfield() -> Path:
    """Répertoire des plugins d'application de QField, selon la plateforme."""
    systeme = platform.system()

    if systeme == "Windows":
        base =  Path.home() / "OneDrive - QC380" / "Documents" / "QField Documents"
        return base / "QField/plugins"

    if systeme == "Darwin":
        return Path.home() / "Library/Application Support/OPENGIS.ch/QField/plugins"

    # Linux et autres
    return Path.home() / ".local/share/OPENGIS.ch/QField/plugins"


def detecter_nom_projet(dossier_projet: Path) -> str | None:
    """Nom (sans extension) du fichier projet QGIS trouvé dans le dossier."""
    for extension in (".qgz", ".qgs"):
        candidats = [
            p for p in dossier_projet.glob(f"*{extension}") if not p.name.endswith("~")
        ]
        if candidats:
            return candidats[0].stem
    return None


def installer_plugin_application(destination_racine: Path, nom: str) -> Path:
    """Copie le plugin dans <destination_racine>/<nom>/, sans vider le dossier.

    Le dossier d'installation n'est jamais supprimé. Un `shutil.rmtree` y était
    tentant — il garantit de partir propre — mais sous OneDrive, ou simplement
    avec QField ouvert, la suppression du dossier lui-même échoue *après* celle
    de son contenu : le plugin se retrouve désinstallé et rien n'est recopié.
    L'erreur arrive donc au pire moment, quand il n'y a plus rien à quoi
    revenir.

    On écrase fichier par fichier, puis on retire les seuls fichiers du plugin
    que la source ne fournit plus. Une copie qui échoue laisse le fichier
    précédent en place, et le script le dit au lieu de faire semblant.
    """
    destination = destination_racine / nom
    destination.mkdir(parents=True, exist_ok=True)

    sources = fichiers_du_plugin()
    echecs = _copier(sources, destination)
    _retirer_les_restes(destination, {fichier.name for fichier in sources})

    if echecs:
        print(f"\n{len(echecs)} fichier(s) n'ont pas pu être remplacés :")
        for echec in echecs:
            print(f"  {echec}")
        sys.exit(
            "\nL'installation est incomplète. Fermez QField (et laissez la "
            "synchronisation OneDrive se terminer), puis relancez."
        )

    print(f"\nPlugin installé dans : {destination}")
    print(
        "Relancez QField. Le plugin apparaît dans Réglages > Plugins, "
        "et son bouton « démarrer » dans la barre d'outils."
    )
    return destination


def _copier(fichiers: list[Path], destination: Path) -> list[str]:
    """Copie les fichiers dans `destination`, en écrasant. Rend les échecs."""
    echecs: list[str] = []

    for fichier in fichiers:
        try:
            shutil.copy2(fichier, destination / fichier.name)
        except OSError as erreur:
            echecs.append(f"{fichier.name} : {erreur.strerror or erreur}")
            print(f"  {fichier.name}  ÉCHEC")
        else:
            print(f"  {fichier.name}")

    return echecs


def _retirer_les_restes(destination: Path, attendus: set[str]) -> None:
    """Supprime les fichiers du plugin que la source ne fournit plus.

    Sans cela, un composant renommé laisserait son ancien `.qml` dans le
    dossier, où l'import implicite de répertoire de QML continuerait de le
    résoudre. Seuls les fichiers portant les extensions du plugin sont
    concernés : ce dossier n'est pas le nôtre, et rien ne dit qu'il ne contient
    que ce qu'on y a mis.
    """
    for reste in sorted(destination.iterdir()):
        if not reste.is_file() or reste.suffix.lower() not in EXTENSIONS:
            continue

        if reste.name in attendus:
            continue

        try:
            reste.unlink()
        except OSError as erreur:
            print(f"  {reste.name}  non supprimé ({erreur.strerror or erreur})")
        else:
            print(f"  {reste.name}  retiré (absent de la source)")


def installer_plugin_projet(dossier_projet: Path) -> Path:
    """Copie les fichiers du plugin à côté du projet et crée <projet>.qml.

    QField cherche un fichier .qml portant exactement le nom du fichier projet.
    Comme tous les composants (MenuPrincipal, IfaPopup, …) résident dans le même
    dossier, ils sont résolus automatiquement par l'import implicite de
    répertoire de QML.
    """
    if not dossier_projet.is_dir():
        sys.exit(f"Dossier introuvable : {dossier_projet}")

    nom_projet = detecter_nom_projet(dossier_projet)
    if nom_projet is None:
        sys.exit(f"Aucun fichier .qgs/.qgz trouvé dans {dossier_projet}")

    for fichier in fichiers_du_plugin():
        shutil.copy2(fichier, dossier_projet / fichier.name)
        print(f"  {fichier.name}")

    # QField accepte aussi le nom sans le suffixe « _qfield » des projets
    # empaquetés par QFieldCloud ; on vise le nom complet, toujours valide.
    point_entree = dossier_projet / f"{nom_projet}.qml"
    shutil.copy2(DOSSIER_SOURCE / "main.qml", point_entree)
    print(f"  {point_entree.name}  (copie de main.qml — point d'entrée)")

    print(f"\nPlugin de projet installé dans : {dossier_projet}")
    print(
        "Publiez le projet via QGIS Desktop > QFieldSync pour le déployer "
        "sur QFieldCloud."
    )
    return point_entree


def construire_zip(nom: str) -> Path:
    """Produit <nom>.zip, avec main.qml à la racine de l'archive."""
    archive = DOSSIER_SOURCE / f"{nom}.zip"

    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zf:
        for fichier in fichiers_du_plugin():
            zf.write(fichier, fichier.name)
            print(f"  {fichier.name}")

    print(f"\nArchive créée : {archive}")
    return archive


def main() -> None:
    parseur = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parseur.add_argument(
        "--app",
        action="store_true",
        help="installer comme plugin d'application (mode par défaut)",
    )
    parseur.add_argument(
        "--projet",
        metavar="DIR",
        help="installer comme plugin de projet dans le dossier indiqué",
    )
    parseur.add_argument(
        "--zip",
        action="store_true",
        help="produire une archive .zip distribuable",
    )
    parseur.add_argument(
        "--dest",
        metavar="DIR",
        help="répertoire des plugins de QField (mode --app)",
    )
    parseur.add_argument(
        "--nom",
        default=NOM_PAR_DEFAUT,
        metavar="NOM",
        help=f"nom du sous-dossier / du zip (défaut : {NOM_PAR_DEFAUT})",
    )
    args = parseur.parse_args()

    if args.projet:
        installer_plugin_projet(Path(args.projet))
        return

    if args.zip:
        construire_zip(args.nom)
        return

    racine = Path(args.dest) if args.dest else dossier_plugins_qfield()
    print(f"Installation du plugin d'application dans : {racine}")
    installer_plugin_application(racine, args.nom)


if __name__ == "__main__":
    main()
