# Une bibliographie partagée

Ce dépôt privé contient l'ensemble des références colligées dans le cadre d'un projet
de recherche collaboratif.

<p><a href="https://www.overleaf.com/docs?snip_uri=https://github.com/sylvainhalle/biblioreo/archive/refs/heads/main.zip"><img src="ouvrir-overleaf-16.png?raw=true" alt="Ouvrir dans Overleaf"/></a></p>

## Prérequis

Pour utiliser ce dépôt, les logiciels suivants sont nécessaires:

- [Git](https://git-scm.org) pour synchroniser le dépôt avec la version en ligne
- [Git LFS](https://docs.github.com/en/repositories/working-with-files/managing-large-files/installing-git-large-file-storage),
  une extension à Git traitant les fichiers binaires de manière particulière
- [JabRef](http://jabref.org/), idéalement le dernier build de la version **6**
  (disponible [ici](https://builds.jabref.org/main/))

Optionnellement, on peut également utiliser:

- Un client visuel pour Git, comme [SmartGit](https://www.syntevo.com/smartgit)
- Puisque BibTeX va de pair avec [LaTeX](https://tug.org/) pour la rédaction
  d'articles, de thèses et de mémoires, une distribution LaTeX comme
  [TeXlive](https://tug.org/texlive) ou [MikTeX](https://miktex.org/)

## Structure

Le dépôt contient deux parties:

- Le fichier `Bibliographie.bib` à la racine, qui contient les références sauvegardées
  par JabRef au format [BibTeX](https://www.bibtex.org/Using/)
- Le dossier `Documents` qui contient les PDF des articles. La bibliographie se
  réfère aux fichiers de ce dossier.

## Utilisation

On obtient une première copie du dépôt en tapant:

    git clone git@github.com:sylvainhalle/xxx.git

...où xxx est le nom particulier donné à une instance de ce gabarit. Ceci 
créera un dossier local appelé `xxx` avec le contenu du
dépôt.

### Modifier la bibliographie

Avant de procéder à une modification du fichier (donc *avant* de démarrer
JabRef), il convient de synchroniser la copie locale avec celle du serveur
GitHub en tapant:

    git pull

On peut ensuite ouvrir `Bibliographie.bib` dans JabRef et lire les
PDF dans le dossier `Documents`.

Une fois les modifications effectuées à la bibliographie
(et les nouveaux PDF éventuellement ajoutés au dossier `Documents`), on sauvegarde
le fichier BibTeX, puis on renvoie les modifications au serveur GitHub.
Ceci se fait en trois étapes:

    git add .

Donne l'instruction au logiciel Git de colliger toutes les modifications apportées
à la copie locale des fichiers du dépôt (ajouts comme suppressions).

    git commit -m "Un message"

Donne l'instruction au logiciel Git "d'emballer" toutes ces modifications dans une
unité appelée un "commit" (qui laissera une trace dans l'historique du dépôt).
Le paramètre `-m` permet de spécifier un message expliquant succintement la nature de
ces modifications --dans notre cas d'utilisation, ces messages n'auront pas une très
grande importance la plupart du temps.

    git push

Officialise les modifications locales sur la copie du dépôt se trouvant sur le serveur.
Dès ce moment, tous les autres utilisateurs lançant la commande `git pull` recevront
la version ainsi mise à jour du dépôt.

## Afficher un résumé

Un script permet de compiler une version "résumé" du contenu de la bibliographie. Pour
ce faire, on tape:

    lualatex Bibliographie

...qui se chargera de produire un document appelé `Bibliographie.pdf`.

## Quelques bonnes pratiques

- Autant que possible, chercher l'entrée BibTeX d'un article sur le site
  [DBLP](https://dblp.org/), et utiliser *cette* entrée pour ajouter dans JabRef.
  Le plus facile est de simplement taper `dblp xxx` dans
  un moteur de recherche, où `xxx` est soit le titre de l'article ou le nom d'un de
  ses auteurs (le site lui-même possède un moteur de recherche). DBLP fournit en général
  les entrées les mieux formatées et les plus complètes, cela devrait donc être un
  premier choix.
- Placer les articles eux-mêmes dans le dossier `Documents` (bien sûr!). Le dépôt est
  configuré pour traiter ces fichiers binaires d'une manière différente des
  fichiers texte (comme `Bibliographie.bib`), mais ce ne sera pas le cas si les
  PDF sont placés ailleurs. Si possible, en liant le PDF dans JabRef (sous
  l'onglet *General/File*), fournir également l'URL d'où le PDF a été obtenu.
- Pour chaque entrée, JabRef, dans son onglet *Comments*, propose un champ générique
  *Comments*, mais également un autre champ appelé *Comments-xxx*, où *xxx* est le
  nom d'un utilisateur (par exemple *Comments-sylvain*). Vous êtes invités à écrire
  vos impressions, résumés, etc. dans le champ correspondant à vous, et également
  de *dater* chacun de vos commentaires.
- Ajouter les articles nouvellement trouvés dans la section *Non trié*. Idéalement,
  seul l'étudiant(e) responsable du projet devrait déplacer ces articles dans d'autres
  catégories, selon sa propre classification, une fois qu'ils auront été lus.

## *Issues*

Puisque le dépôt est hébergé sur GitHub, il est recommandé d'utiliser le
*issue tracker* (désolé, pas de traduction française évidente) pour assigner des tâches
précises à certains collaborateurs.