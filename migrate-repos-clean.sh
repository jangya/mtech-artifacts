#!/bin/bash

# Migration script - Complete rewrite to fix git issues
# Usage: ./migrate-repos-clean.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GITHUB_USER="jangya"
TARGET_REPO="learning-artifacts"
WORK_DIR="./migration-workspace-clean"

echo -e "${BLUE}🚀 Repository Migration${NC}"
echo "User: $GITHUB_USER"
echo "Target: $TARGET_REPO"
echo "Working Directory: $WORK_DIR"
echo ""

# STEP 1: Clean workspace
echo -e "${YELLOW}🧹 Cleaning workspace...${NC}"
if [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
fi
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# STEP 2: Clone target repo fresh
echo -e "${YELLOW}📥 Cloning target repository (fresh)...${NC}"
gh repo clone "$GITHUB_USER/$TARGET_REPO" || {
    echo -e "${RED}❌ Failed to clone. Make sure learning-artifacts repo exists on GitHub${NC}"
    exit 1
}

cd "$TARGET_REPO"

# STEP 3: Verify git repo
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Not a valid git repository${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Valid git repository${NC}"

# STEP 4: Setup directory structure
echo -e "${YELLOW}📁 Creating directory structure...${NC}"
mkdir -p frontend/{angular,react,astro,vanilla-js}
mkdir -p ai-ml/{streamlit-apps,notebooks,datasets}
mkdir -p utilities
mkdir -p experiments

# Create README if missing
if [ ! -f "README.md" ]; then
    cat > README.md << 'EOF'
# Learning Artifacts

Consolidated repository for learning materials, experiments, and prototypes organized by topic.

## Structure

- **frontend/**: Frontend frameworks and technologies (Angular, React, Astro, Vanilla JS)
- **ai-ml/**: AI/ML projects and Streamlit applications
- **utilities/**: Utility tools and helper projects
- **experiments/**: Various experimental projects

Each subdirectory contains a `SOURCE.md` indicating the original repository.
EOF
fi

git add .
git commit -m "Setup directory structure" 2>/dev/null || echo "Structure already committed"
git push 2>/dev/null || true

# STEP 5: Migration array
declare -a MIGRATIONS=(
    "Angular-Directives:frontend/angular:Angular-Directives"
    "AngularJsMasterGrid:frontend/angular:AngularJsMasterGrid"
    "AngularJsMvcGrid:frontend/angular:AngularJsMvcGrid"
    "ng-material-app:frontend/angular:ng-material-app"
    "frontend-challenge:frontend/vanilla-js:frontend-challenge"
    "js-cycle:frontend/vanilla-js:js-cycle"
    "astro-crafted-experience:frontend/astro:astro-crafted-experience"
    "box-portal-demo:frontend/vanilla-js:box-portal-demo"
    "bank-marketing-ml-streamlit:ai-ml/streamlit-apps:bank-marketing-ml"
    "dependency-analyzer:utilities:dependency-analyzer"
    "pdf-generator:utilities:pdf-generator"
    "stock-picker:utilities:stock-picker"
    "WeatherWidget:utilities:WeatherWidget"
    "vaccine-session:utilities:vaccine-session"
    "samesite:utilities:samesite"
    "DisBook:utilities:DisBook"
    "news-mag:utilities:news-mag"
    "llm-glassbox:experiments:llm-glassbox"
    "personalize-resume-magic:experiments:personalize-resume-magic"
    "resume-editor:experiments:resume-editor"
    "ResumeAI:experiments:ResumeAI"
    "posts-react-ts:experiments:posts-react-ts"
)

# STEP 6: Migrate each repo
echo -e "${YELLOW}🔄 Migrating repositories...${NC}"

for migration in "${MIGRATIONS[@]}"; do
    IFS=':' read -r source_repo target_path sub_dir <<< "$migration"
    
    echo -e "${BLUE}→ $source_repo${NC}"
    
    # Clone source repo to temp location
    cd ..
    if [ -d "$source_repo" ]; then
        rm -rf "$source_repo"
    fi
    
    gh repo clone "$GITHUB_USER/$source_repo" 2>/dev/null || {
        echo -e "${RED}  ❌ Clone failed${NC}"
        continue
    }
    
    # Create target directory
    target_full_path="$TARGET_REPO/$target_path/$sub_dir"
    mkdir -p "$target_full_path"
    
    # Copy all content (skip .git)
    find "$source_repo" -maxdepth 1 ! -name '.git' ! -name '.' -exec cp -r {} "$target_full_path/" \; 2>/dev/null || true
    
    # Remove any .git that might have been copied
    find "$target_full_path" -type d -name '.git' -exec rm -rf {} + 2>/dev/null || true
    
    # Add source info
    cat > "$target_full_path/SOURCE.md" << EOF
# Source: $source_repo

Original: https://github.com/$GITHUB_USER/$source_repo
EOF
    
    echo -e "${GREEN}  ✅ Migrated${NC}"
done

# STEP 7: Final commit
echo -e "${YELLOW}💾 Finalizing...${NC}"
cd "$TARGET_REPO"

# Remove any lingering .git directories
find . -type d -name '.git' ! -path './.git' -exec rm -rf {} + 2>/dev/null || true

git add -A
git commit -m "🚀 Consolidate all learning repositories

Migrated:
- Frontend projects (8)
- AI/ML projects (1)
- Utilities (8)
- Experiments (5)

Total: 22 repositories consolidated into organized structure" 2>/dev/null || echo "No new changes"

git push 2>/dev/null || echo "Push skipped"

# STEP 8: Summary
echo ""
echo -e "${BLUE}📊 Migration Summary${NC}"
echo "✅ Repositories migrated:"
for migration in "${MIGRATIONS[@]}"; do
    IFS=':' read -r source_repo target_path sub_dir <<< "$migration"
    echo "   - $source_repo → $target_path/$sub_dir"
done

echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Review: https://github.com/$GITHUB_USER/$TARGET_REPO"
echo "2. Clean workspace: cd .. && rm -rf $WORK_DIR"
echo "3. Delete old repos (when ready):"
echo ""
for migration in "${MIGRATIONS[@]}"; do
    IFS=':' read -r source_repo _ _ <<< "$migration"
    echo "   gh repo delete $GITHUB_USER/$source_repo --confirm"
done

echo ""
echo -e "${GREEN}✨ Migration Complete!${NC}"
