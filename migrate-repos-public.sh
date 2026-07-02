#!/bin/bash

# Migration script - Handle public repos only, skip private
# Usage: ./migrate-repos-public.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GITHUB_USER="jangya"
TARGET_REPO="learning-artifacts"
WORK_DIR="./migration-workspace-public"

echo -e "${BLUE}🚀 Repository Migration (Public Repos Only)${NC}"
echo ""

# STEP 1: Clean workspace
echo -e "${YELLOW}🧹 Cleaning workspace...${NC}"
if [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
fi
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# STEP 2: Clone target repo fresh
echo -e "${YELLOW}📥 Cloning target repository...${NC}"
gh repo clone "$GITHUB_USER/$TARGET_REPO" || {
    echo -e "${RED}❌ Failed to clone. Make sure learning-artifacts exists${NC}"
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

## Status

Note: Private repositories are not included in this consolidation. Add them separately if needed.
EOF
fi

git add .
git commit -m "Setup directory structure" 2>/dev/null || echo "Structure already committed"
git push 2>/dev/null || true

# STEP 5: Migration array - PUBLIC REPOS ONLY
declare -a MIGRATIONS=(
    # Frontend - Angular (PUBLIC)
    "Angular-Directives:frontend/angular:Angular-Directives"
    "AngularJsMasterGrid:frontend/angular:AngularJsMasterGrid"
    "AngularJsMvcGrid:frontend/angular:AngularJsMvcGrid"
    "ng-material-app:frontend/angular:ng-material-app"
    
    # Frontend - Other (PUBLIC)
    "frontend-challenge:frontend/vanilla-js:frontend-challenge"
    "js-cycle:frontend/vanilla-js:js-cycle"
    
    # AI/ML (PUBLIC)
    "bank-marketing-ml-streamlit:ai-ml/streamlit-apps:bank-marketing-ml"
    
    # Utilities (PUBLIC)
    "pdf-generator:utilities:pdf-generator"
    "stock-picker:utilities:stock-picker"
    "WeatherWidget:utilities:WeatherWidget"
    "vaccine-session:utilities:vaccine-session"
    "samesite:utilities:samesite"
    "DisBook:utilities:DisBook"
    "news-mag:utilities:news-mag"
    "posts-react-ts:utilities:posts-react-ts"
    "spytrac:utilities:spytrac"
    "studio:utilities:studio"
    "interview:utilities:interview"
    
    # Experiments (PUBLIC)
    "llm-glassbox:experiments:llm-glassbox"
    "resume-editor:experiments:resume-editor"
    "my-dream-app:experiments:my-dream-app"
    "portfolio-archieve:experiments:portfolio-archieve"
    "jangya.github.io:experiments:jangya-github-io"
)

# STEP 6: Migrate each repo
echo -e "${YELLOW}🔄 Migrating repositories...${NC}"

MIGRATED=0
FAILED=0

for migration in "${MIGRATIONS[@]}"; do
    IFS=':' read -r source_repo target_path sub_dir <<< "$migration"
    
    echo -ne "${BLUE}→ $source_repo${NC}"
    
    # Clone source repo to temp location
    cd ..
    if [ -d "$source_repo" ]; then
        rm -rf "$source_repo"
    fi
    
    # Try to clone with timeout
    timeout 30 gh repo clone "$GITHUB_USER/$source_repo" 2>/dev/null || {
        echo -e " ${RED}❌ Clone failed${NC}"
        FAILED=$((FAILED + 1))
        continue
    }
    
    # Create target directory
    target_full_path="$TARGET_REPO/$target_path/$sub_dir"
    mkdir -p "$target_full_path"
    
    # Copy all content
    find "$source_repo" -maxdepth 1 ! -name '.git' ! -name '.' -exec cp -r {} "$target_full_path/" \; 2>/dev/null || true
    
    # Remove any .git that might have been copied
    find "$target_full_path" -type d -name '.git' -exec rm -rf {} + 2>/dev/null || true
    
    # Add source info
    cat > "$target_full_path/SOURCE.md" << EOF
# Source: $source_repo

Original: https://github.com/$GITHUB_USER/$source_repo
EOF
    
    echo -e " ${GREEN}✅${NC}"
    MIGRATED=$((MIGRATED + 1))
done

echo ""
echo -e "${YELLOW}💾 Finalizing...${NC}"
cd "$TARGET_REPO"

# Remove any lingering .git directories
find . -type d -name '.git' ! -path './.git' -exec rm -rf {} + 2>/dev/null || true

git add -A
git commit -m "🚀 Consolidate public learning repositories

Migrated:
- Frontend projects (Angular, JS, challenges)
- AI/ML projects (Streamlit)
- Utilities (tools, experiments)
- Experiments (various projects)

Total: $MIGRATED repositories consolidated

Note: Private repositories skipped. Add them manually when ready." 2>/dev/null || echo "No new changes to commit"

git push origin main 2>/dev/null || git push origin master 2>/dev/null || echo "Push skipped"

# STEP 7: Summary
echo ""
echo -e "${BLUE}📊 Migration Summary${NC}"
echo "===================="
echo -e "${GREEN}✅ Migrated: $MIGRATED${NC}"
echo -e "${RED}❌ Failed: $FAILED${NC}"
echo ""

if [ $MIGRATED -gt 0 ]; then
    echo -e "${YELLOW}📝 Migrated Repositories:${NC}"
    for migration in "${MIGRATIONS[@]}"; do
        IFS=':' read -r source_repo target_path sub_dir <<< "$migration"
        echo "   ✓ $source_repo"
    done
fi

echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Review: https://github.com/$GITHUB_USER/$TARGET_REPO"
echo "2. Clean workspace: rm -rf $WORK_DIR"
echo "3. When ready, delete old public repos:"
echo ""
for migration in "${MIGRATIONS[@]}"; do
    IFS=':' read -r source_repo _ _ <<< "$migration"
    echo "   gh repo delete $GITHUB_USER/$source_repo --confirm"
done
echo ""
echo "4. Private repos (to add later):"
echo "   - astro-crafted-experience"
echo "   - box-portal-demo"
echo "   - dependency-analyzer"
echo "   - personalize-resume-magic"
echo "   - ResumeAI"
echo "   - smart-queue"

echo ""
echo -e "${GREEN}✨ Migration Complete!${NC}"
