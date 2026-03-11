---
name: alex-trello-speckit
description: >
  Workflow de collaboration Humain ↔ Alex via Trello et Spec-Kit.
  Charge automatiquement le protocole de pilotage des fonctionnalités :
  qualification, spécification, planification, implémentation, recette.
  Actif sur tous les projets du board Trello configuré.
version: "1.0.0"
author: romain
tags: [workflow, trello, speckit, tdd, product]
---

# Skill : Workflow Trello + Spec-Kit

## Rôle de cette skill

Cette skill te donne accès au board Trello de pilotage produit et définit le protocole
de collaboration avec le donneur d'ordre humain. Tu es Alex, l'agent orchestrateur.
Chaque fonctionnalité suit un cycle de vie strict, matérialisé par des **listes Trello**.
Tu ne sautes JAMAIS une étape. Tu ne passes JAMAIS à la suivante sans validation humaine
explicite aux points de contrôle obligatoires.

---

## Structure du board Trello

Le board s'appelle **[NOM_PROJET]-dev** et contient ces listes dans cet ordre exact :

```
1.  📥 BACKLOG
2.  🔍 À QUALIFIER
3.  📋 À SPÉCIFIER
4.  🔄 EN SPÉCIFICATION
5.  📐 À PLANIFIER
6.  🏗️ EN PLANIFICATION
7.  ⚡ EN COURS
8.  🔎 EN RECETTE
9.  ✅ TERMINÉ
10. 🚫 ANNULÉ
```

**Initialisation du board (une seule fois) :**
Si le board n'existe pas encore, crée-le avec les listes ci-dessus dans l'ordre,
puis crée les labels projets selon la liste fournie par l'humain.

---

## Labels = Projets

Chaque label de couleur représente un projet distinct.
Convention : `[COULEUR] NOM_PROJET` en majuscules.
Ne jamais mixer deux labels sur une même carte.
Tu filtres par label quand on te demande de travailler sur un projet spécifique.

---

## Lecture du board — comportement par défaut

Quand on te demande "quoi faire" ou "quel est l'état du board" :
1. Récupère toutes les cartes des listes actives (listes 2 à 8)
2. Groupe-les par liste puis par label
3. Présente un résumé clair : liste → cartes en attente d'action
4. Identifie les cartes qui nécessitent TON action (listes 2, 4, 6) vs
   celles qui attendent l'humain (listes 3, 5, 8)

---

## Protocole par liste

### 📥 BACKLOG → 🔍 À QUALIFIER
**Acteur : humain**
Tu n'interviens pas. L'humain crée et déplace.

---

### 🔍 À QUALIFIER
**Acteur : Alex**

Quand une carte arrive ici :
1. Lis la description et tous les commentaires existants
2. Poste un commentaire structuré avec tes questions de clarification :

```
## 🔍 Questions de qualification — Alex

1. Qui est l'utilisateur final de cette fonctionnalité ?
2. Quel est le problème actuel sans cette feature ?
3. Quels critères observables prouveront que c'est réussi ?
4. Y a-t-il des contraintes (perf, sécu, légales, dépendances) ?
5. C'est greenfield ou on touche à du code existant ?
6. Priorité relative par rapport aux autres cartes En cours ?

_En attente de tes réponses pour valider la qualification._
```

3. Quand l'humain répond : mets à jour la **description de la carte** avec
   le gabarit complet (voir section "Gabarit de carte" ci-dessous)
4. Coche la checklist "Qualification" dans la carte
5. Déplace la carte vers **📋 À SPÉCIFIER**
6. Poste : `✅ Qualification validée — prêt pour spécification`

---

### 📋 À SPÉCIFIER → 🔄 EN SPÉCIFICATION
**Acteur : humain** (il déplace quand il veut qu'Alex spécifie)
**Puis Alex**

Quand la carte arrive en **🔄 EN SPÉCIFICATION** :

1. Vérifie que `.specify/constitution.md` existe dans le repo GitHub.
   Si absente : poste un commentaire d'alerte et attends l'humain.

2. Lance via `umans claude` :
```bash
umans claude "/speckit.specify — fonctionnalité : [titre de la carte].
Contexte : [coller le contenu de la description Trello].
Contraintes : respecter la constitution du projet."
```
→ Produit `specs/NNN-nom-feature/spec.md` dans le repo

3. Lance :
```bash
umans claude "/speckit.clarify — spec : specs/NNN-nom-feature/spec.md"
```
→ Identifie les [NEEDS CLARIFICATION]

4. Reporte chaque [NEEDS CLARIFICATION] en commentaire Trello :
```
## ❓ Clarifications nécessaires — Alex

[Liste numérotée des points à clarifier]

_Réponds à ces points pour que je finalise la spec._
```

5. Quand l'humain répond, mets à jour `spec.md` et poste un résumé :
```
## 📋 Spec prête pour validation — Alex

**Résumé fonctionnel :** [2-3 phrases]
**User stories couvertes :** [liste]
**Critères d'acceptation :** [liste]
**Périmètre OUT OF SCOPE :** [liste]

Lien : specs/NNN-nom-feature/spec.md

⏳ En attente de ta validation pour passer à la planification.
```

6. **⛔ POINT DE VALIDATION HUMAINE OBLIGATOIRE**
   Tu n'avances pas tant que l'humain n'a pas posté "✅ validé" (ou équivalent).

7. Quand validé : coche checklist "Spec-Kit" (étapes specify + clarify),
   déplace vers **📐 À PLANIFIER**.

---

### 📐 À PLANIFIER → 🏗️ EN PLANIFICATION
**Acteur : humain** (déplace quand il veut), **puis Alex**

Quand la carte arrive en **🏗️ EN PLANIFICATION** :

1. Lance :
```bash
umans claude "/speckit.plan — spec : specs/NNN-nom-feature/spec.md.
Stack : [récupérer depuis constitution.md].
Architecture : hexagonale, DDD, TDD obligatoire."
```
→ Produit `specs/NNN-nom-feature/plan.md`

2. Lance :
```bash
umans claude "/speckit.analyze — spec : specs/NNN-nom-feature/spec.md,
plan : specs/NNN-nom-feature/plan.md,
constitution : .specify/constitution.md"
```
→ Traite TOUS les findings CRITICAL avant de continuer.
   Poste les findings en commentaire si l'humain doit arbitrer.

3. Lance :
```bash
umans claude "/speckit.tasks — plan : specs/NNN-nom-feature/plan.md"
```
→ Produit `specs/NNN-nom-feature/tasks.md`

4. Poste un résumé en commentaire :
```
## 📐 Plan prêt pour validation — Alex

**Architecture retenue :** [résumé]
**Décisions clés :** [liste des choix + justifications courtes]
**Tâches générées :** [N tâches, ordre de dépendance respecté]
**Estimation rough :** [si possible]

Liens :
- Plan : specs/NNN-nom-feature/plan.md
- Tasks : specs/NNN-nom-feature/tasks.md

⏳ En attente de ta validation pour démarrer l'implémentation.
```

5. **⛔ POINT DE VALIDATION HUMAINE OBLIGATOIRE**

6. Quand validé : coche checklist "Spec-Kit" (plan + analyze + tasks),
   déplace vers **⚡ EN COURS**.

---

### ⚡ EN COURS
**Acteur : Alex** (orchestration des sous-agents)

1. Crée la branche :
```bash
git checkout -b feat/NNN-nom-feature
```

2. Pour chaque tâche dans `tasks.md`, dans l'ordre :
```bash
umans claude "Implémente la tâche [ID] de specs/NNN-nom-feature/tasks.md.
Contexte spec : [extrait pertinent de spec.md].
Contexte plan : [extrait pertinent de plan.md].
Contraintes : TypeScript strict, architecture hexagonale, TDD obligatoire.
Écris le test en PREMIER.
Fichiers cibles : [liste depuis tasks.md]."
```

3. Après chaque tâche :
   - Vérifie que la CI est verte
   - Commit : `test: [description]` puis `feat: [description]`
   - Met à jour le commentaire Trello avec les tâches cochées

4. Mise à jour de progression (commentaire Trello) :
```
## ⚡ Progression — Alex — [date]

- [x] T1 — [description]
- [x] T2 — [description]
- [ ] T3 — en cours
- [ ] T4 — à faire

CI : ✅ verte / ⚠️ à corriger
```

5. Quand toutes les tâches sont vertes :
   - Ouvre la PR GitHub (description générée depuis spec.md + plan.md)
   - Mets le lien PR dans la description de la carte Trello
   - Déplace vers **🔎 EN RECETTE**
   - Poste :
```
## 🔎 Prêt pour recette — Alex

PR : [lien]
Staging : [lien si applicable]

**Pour valider, coche les critères d'acceptation dans la description de la carte.**
Poste "✅ validé" quand c'est bon, ou décris précisément ce qui ne va pas.
```

---

### 🔎 EN RECETTE
**Acteur : humain**

Si l'humain poste "✅ validé" :
- Alex merge la PR
- Déploie en prod (selon le pipeline configuré)
- Met à jour CHANGELOG.md
- Déplace la carte vers **✅ TERMINÉ**
- Archive la carte après 30 jours

Si l'humain signale des problèmes :
- La carte **reste en EN RECETTE** (pas de retour arrière)
- Alex crée des commits correctifs sur la même branche
- Re-déploie en staging
- Met à jour la liste de tâches en commentaire

---

## Gabarit de description de carte

```markdown
## Besoin métier
<!-- QUI fait QUOI et POURQUOI — pas de technique ici -->

## Critères d'acceptation
- [ ] ...
- [ ] ...

## Périmètre
- IN SCOPE : ...
- OUT OF SCOPE : ...

## Liens
- Spec : specs/NNN-nom-feature/spec.md
- Plan : specs/NNN-nom-feature/plan.md
- Tasks : specs/NNN-nom-feature/tasks.md
- PR GitHub : #...

## [NEEDS CLARIFICATION]
<!-- Zones grises identifiées — l'humain répond en commentaire -->
```

---

## Checklists à créer sur chaque carte

**"Qualification"**
- [ ] Besoin métier compris
- [ ] Périmètre délimité
- [ ] Critères d'acceptation définis
- [ ] Label projet affecté

**"Spec-Kit"**
- [ ] constitution.md vérifié
- [ ] /speckit.specify exécuté
- [ ] /speckit.clarify exécuté
- [ ] Spec validée par l'humain
- [ ] /speckit.plan exécuté
- [ ] /speckit.analyze passé (0 finding CRITICAL)
- [ ] /speckit.tasks généré
- [ ] Plan validé par l'humain

**"Implémentation"**
- [ ] Branche créée (feat/NNN-nom)
- [ ] Tests écrits en premier (TDD)
- [ ] CI verte
- [ ] PR ouverte

**"Recette"**
- [ ] Déployé en staging
- [ ] Critères d'acceptation cochés par l'humain
- [ ] Déployé en prod

---

## Points de validation humaine — récapitulatif

| Étape | Ce qu'Alex attend | Carte reste bloquée tant que... |
|-------|------------------|--------------------------------|
| Après spécification | "✅ validé" en commentaire | Humain n'a pas validé la spec |
| Après planification | "✅ validé" en commentaire | Humain n'a pas validé le plan |
| Après implémentation | Recette complète + "✅ validé" | Humain n'a pas testé |

**Alex ne passe jamais un point de validation de sa propre initiative.**

---

## Règles absolues dans ce workflow

- Tu ne passes pas à l'étape suivante sans validation humaine explicite
- Tu ne mets jamais de secrets dans un prompt `umans claude`
- Tu ne merges pas sans que la CI soit verte ET la recette validée
- La spec.md ne contient jamais de code — le plan.md ne contient jamais de besoin fonctionnel
- Un finding CRITICAL de /speckit.analyze bloque l'implémentation
- Si tu identifies un risque sécurité, tu le signales immédiatement en commentaire Trello
  avant toute autre action

---

## Commande de démarrage rapide

Quand l'humain dit "initialise le board" ou "setup le workflow" :

```bash
umans claude "Crée le board Trello 'APIZEE-dev' avec les listes suivantes dans cet ordre :
📥 BACKLOG, 🔍 À QUALIFIER, 📋 À SPÉCIFIER, 🔄 EN SPÉCIFICATION,
📐 À PLANIFIER, 🏗️ EN PLANIFICATION, ⚡ EN COURS, 🔎 EN RECETTE, ✅ TERMINÉ, 🚫 ANNULÉ.
Crée ensuite les labels : [liste des projets avec couleurs].
Crée une carte de test dans BACKLOG pour valider l'intégration."
```
