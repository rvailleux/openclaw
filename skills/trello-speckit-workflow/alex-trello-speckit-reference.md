# Système de collaboration Humain ↔ Alex
## Trello + Spec-Kit + OpenClaw — Guide de référence complet

> **Deux fichiers à déployer :**
> - `~/.openclaw/workspace/skills/alex-trello-speckit/SKILL.md` → chargé automatiquement par OpenClaw
> - `docs/workflow/alex-trello-speckit-reference.md` → ce fichier, dans le repo GitHub

---

## 1. Architecture du système

```
┌─────────────────────────────────────────────────────────────────┐
│                        HUMAIN (donneur d'ordre)                  │
│  Crée cartes · Répond aux questions · Valide spec · Valide plan  │
│  Fait la recette · Donne le GO final                             │
└──────────────────────────┬──────────────────────────────────────┘
                           │ Trello (lecture/écriture)
┌──────────────────────────▼──────────────────────────────────────┐
│                     ALEX (agent OpenClaw)                        │
│  Qualifie · Spécifie · Planifie · Orchestre · Documente         │
├──────────────────────────┬──────────────────────────────────────┤
│   SKILL.md chargée       │   Trello MCP (outils natifs)         │
│   dans contexte OpenClaw │   GitHub (code + CI/CD)              │
└──────────────────────────┼──────────────────────────────────────┘
                           │ umans claude
┌──────────────────────────▼──────────────────────────────────────┐
│                   SOUS-AGENTS (via umans claude)                 │
│   /speckit.specify  /speckit.plan  /speckit.tasks               │
│   /speckit.analyze  /speckit.implement  /speckit.clarify        │
└─────────────────────────────────────────────────────────────────┘
```

**Qui fait quoi, en un mot :**

| Acteur | Responsabilité |
|--------|---------------|
| Humain | Vision, validation, recette |
| Alex | Coordination, specs, architecture, intégration |
| Sous-agents | Exécution atomique (spec, plan, code) |
| Trello | Tableau de bord partagé, trace des décisions |
| GitHub | Source of truth technique |

---

## 2. Installation

### 2.1 Déployer la skill OpenClaw

```bash
# Créer le dossier de la skill
mkdir -p ~/.openclaw/workspace/skills/alex-trello-speckit

# Copier le SKILL.md
cp docs/workflow/SKILL.md ~/.openclaw/workspace/skills/alex-trello-speckit/SKILL.md

# Recharger les skills dans OpenClaw
# (redémarrer le gateway ou demander à Alex : "refresh skills")
```

OpenClaw découvre automatiquement les skills au démarrage — le fichier SKILL.md est chargé dans le contexte de l'agent, ses instructions deviennent actives immédiatement.

### 2.2 Vérifier le connecteur Trello

Dans `~/.openclaw/openclaw.json`, vérifier :

```json
{
  "tools": {
    "allow": ["trello", "group:fs", "group:runtime"]
  },
  "agents": {
    "list": [
      {
        "id": "alex",
        "tools": {
          "profile": "coding",
          "allow": ["trello"]
        }
      }
    ]
  }
}
```

OpenClaw expose un système de profils d'outils (`tools.profile`) et de listes d'autorisation/interdiction (`tools.allow` / `tools.deny`) — `deny` gagne toujours sur `allow`.

### 2.3 Initialiser le board Trello

Dire à Alex :
```
"Initialise le board Trello pour le projet APIZEE avec les projets suivants :
NEXUS (rouge), PORTAIL (bleu), APPVISIO (vert), MEET (jaune), INFRA (violet)"
```

Alex crée le board, les 10 listes, et les labels en une seule passe.

### 2.4 Initialiser Spec-Kit dans le repo

```bash
# À la racine du repo
mkdir -p .specify specs docs/adr

# Créer la constitution (obligatoire avant toute spec)
touch .specify/constitution.md
# → remplir avec le template section 6 ci-dessous
```

---

## 3. Les 10 listes du board — rôles et responsabilités

| Liste | Acteur qui agit | Condition pour avancer |
|-------|----------------|----------------------|
| 📥 BACKLOG | Humain | L'humain déplace vers À QUALIFIER |
| 🔍 À QUALIFIER | Alex | Qualification complète + humain a répondu aux questions |
| 📋 À SPÉCIFIER | Humain | L'humain déplace quand il veut qu'Alex spécifie |
| 🔄 EN SPÉCIFICATION | Alex | **⛔ Spec validée par l'humain** |
| 📐 À PLANIFIER | Humain | L'humain déplace quand il veut qu'Alex planifie |
| 🏗️ EN PLANIFICATION | Alex | **⛔ Plan + tasks validés par l'humain** |
| ⚡ EN COURS | Alex | PR ouverte + CI verte |
| 🔎 EN RECETTE | Humain | **⛔ Recette OK + "✅ validé" en commentaire** |
| ✅ TERMINÉ | Alex | Archivage après 30 jours |
| 🚫 ANNULÉ | Humain/Alex | Raison documentée en commentaire |

Les **⛔ points de validation** sont des barrières absolues. Alex ne les franchit jamais seul.

---

## 4. Cycle de vie d'une carte — vue complète

```
HUMAIN crée carte
       │
       ▼
📥 BACKLOG ──(humain déplace)──► 🔍 À QUALIFIER
                                        │
                              Alex pose questions
                              Humain répond
                              Alex met à jour description
                                        │
                                        ▼
                                📋 À SPÉCIFIER
                                        │
                              (humain déplace quand prêt)
                                        │
                                        ▼
                               🔄 EN SPÉCIFICATION
                                        │
                              Alex : /speckit.specify
                              Alex : /speckit.clarify
                              Alex poste résumé spec
                                        │
                                  ⛔ VALIDATION
                               humain dit "✅ validé"
                                        │
                                        ▼
                                📐 À PLANIFIER
                                        │
                              (humain déplace quand prêt)
                                        │
                                        ▼
                               🏗️ EN PLANIFICATION
                                        │
                              Alex : /speckit.plan
                              Alex : /speckit.analyze
                              Alex : /speckit.tasks
                              Alex poste résumé plan
                                        │
                                  ⛔ VALIDATION
                               humain dit "✅ validé"
                                        │
                                        ▼
                                  ⚡ EN COURS
                                        │
                              Alex orchestre sous-agents
                              TDD : test → green → refactor
                              Commits conventionnels
                              CI verte à chaque tâche
                              PR ouverte
                                        │
                                        ▼
                                🔎 EN RECETTE
                                        │
                              Humain teste sur staging
                              Humain coche critères
                                        │
                                  ⛔ VALIDATION
                               humain dit "✅ validé"
                                        │
                              Alex merge + déploie prod
                              Alex met à jour CHANGELOG
                                        │
                                        ▼
                                  ✅ TERMINÉ
```

---

## 5. Conventions de nommage

### Cartes Trello
```
[PROJET] Verbe + objet métier
ex : [NEXUS] Afficher le statut temps réel d'une session
ex : [PORTAIL] Exporter les statistiques d'usage en CSV
ex : [INFRA] Migrer les secrets vers Vault
```

### Branches Git
```
feat/NNN-nom-en-kebab-case
ex : feat/042-export-stats-csv
```

### Dossiers Spec-Kit
```
specs/
  042-export-stats-csv/
    spec.md
    plan.md
    tasks.md
    implementation-details/
```

### Commits
```
test: ajouter tests unitaires ExportService
feat: implémenter export CSV des statistiques
docs: mettre à jour README section exports
```

---

## 6. Template constitution.md

À placer dans `.specify/constitution.md` — **obligatoire avant toute spec** :

```markdown
# Constitution du projet [NOM]

> Mise à jour : [DATE] — Tout écart est une finding CRITICAL dans /speckit.analyze

## Architecture — non-négociable
- Architecture hexagonale : le domaine ne connaît pas l'infrastructure
- DDD : entités métier sans dépendance BDD ou framework
- Pas de logique métier dans les contrôleurs / handlers / routes
- CQRS si la feature implique des lectures complexes découplées des écritures

## Qualité du code — non-négociable
- TDD strict : test AVANT implémentation, sans exception
- Couverture domaine > 90%
- Conventional Commits sur toutes les branches
- Pas de `any` en TypeScript (ou équivalent dans le langage du projet)
- Nommage intentionnel : pas de `data`, `result`, `temp`, `misc`

## Sécurité — non-négociable
- Aucun secret dans le code, les specs, les prompts sous-agents
- Validation des inputs côté serveur systématique
- OWASP Top 10 vérifié à chaque PR
- Dependabot activé, findings HIGH traités sous 48h

## Stack technique
- Backend : [préciser]
- Frontend : [préciser]
- Base de données : [préciser]
- Test runner : [préciser]
- CI : GitHub Actions

## Contraintes spécifiques
- [Ajouter les contraintes propres au projet]

## Historique des amendments
| Date | Changement | ADR |
|------|-----------|-----|
| [DATE] | Création | — |
```

---

## 7. Mapping Trello ↔ Spec-Kit ↔ GitHub

```
TRELLO LIST               SPEC-KIT COMMAND              GITHUB ARTIFACT
─────────────────────────────────────────────────────────────────────────
À QUALIFIER          →    (questions Alex)           →   (rien)
EN SPÉCIFICATION     →    /speckit.specify            →   specs/NNN/spec.md
                          /speckit.clarify
À PLANIFIER          →    (validation humaine)        →   (rien)
EN PLANIFICATION     →    /speckit.plan               →   specs/NNN/plan.md
                          /speckit.analyze             →   specs/NNN/tasks.md
                          /speckit.tasks               →   docs/adr/NNN.md
EN COURS             →    /speckit.implement          →   feat/NNN (branche)
                          (umans claude ×N tasks)      →   commits TDD
                                                       →   CI verte
EN RECETTE           →    (spec figée)                →   PR ouverte
                                                       →   staging déployé
TERMINÉ              →    (archivage)                 →   merge main
                                                       →   tag release
                                                       →   CHANGELOG.md
```

---

## 8. FAQ — Cas limites

**Q : La spec évolue pendant l'implémentation ?**  
→ Stop. Alex met à jour `spec.md`, poste un commentaire de changement en Trello,
demande une re-validation de la spec modifiée, puis reprend. La carte reste en EN COURS.

**Q : La recette révèle un besoin non couvert dans la spec initiale ?**  
→ Nouvelle carte dans BACKLOG. La carte courante finalise ce qui était prévu.
On ne modifie pas une spec après le début de la recette.

**Q : Un finding CRITICAL dans /speckit.analyze que l'humain veut ignorer ?**  
→ Alex documente le désaccord en commentaire Trello + crée un ADR avec la décision.
L'humain doit l'approuver explicitement. C'est sa responsabilité assumée.

**Q : Deux cartes interdépendantes ?**  
→ Lien Trello entre les deux cartes + mention dans les deux `spec.md`.
La carte dépendante ne passe pas en EN COURS tant que sa dépendance n'est pas en TERMINÉ.

**Q : Un secret apparaît dans un output de sous-agent ?**  
→ Alerte immédiate en commentaire Trello. Rotation du secret avant tout autre action.
Post-mortem documenté. La carte est bloquée jusqu'à résolution.

**Q : Comment adapter les noms des listes si le board existe déjà ?**  
→ Renommer les listes existantes pour qu'elles correspondent exactement aux 10 noms
définis. Alex se base sur les noms pour router les cartes.

---

## 9. Checklist de démarrage (une fois)

```
□ ~/.openclaw/workspace/skills/alex-trello-speckit/SKILL.md déployé
□ OpenClaw gateway redémarré (skills rechargés)
□ Connecteur Trello vérifié dans openclaw.json (tools.allow)
□ Board Trello créé avec les 10 listes + labels projets
□ .specify/constitution.md créé et rempli dans le repo
□ specs/ et docs/adr/ créés dans le repo
□ Carte de test créée dans BACKLOG pour valider le workflow end-to-end
□ Alex a confirmé qu'il "voit" le board (lui demander de lister les listes)
```

---

*Document maintenu dans `docs/workflow/alex-trello-speckit-reference.md`*  
*SKILL.md maintenu dans `~/.openclaw/workspace/skills/alex-trello-speckit/SKILL.md`*  
*Mettre les deux à jour ensemble si le process évolue.*
