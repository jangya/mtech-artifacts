#!/bin/bash

# Migration script to consolidate repos into learning-artifacts
# Fixed version: removes .git directories and handles empty repos
# Usage: ./migrate-repos-fixed.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_USER="jangya"
TARGET_REPO="learning-artifacts"
WORK_DIR="./migration-workspace"
LOG_FILE="migration.log"

# Initialize log
echo "Starting repository migration at $(date)" > "$LOG_FILE"

echo -e "${BLUE}🚀 Starting migration to $TARGET_REPO${NC}"

# Step 1: Create work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Step 2: Clone target repo
echo -e "${YELLOW}📥 Cloning target repository...${NC}"
if [ -d "$TARGET_REPO" ]; then
    echo "Target repo already exists, checking for branches..."
    cd "$TARGET_REPO"
    # Try to pull, but don't fail if repo is empty
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "No remote branches yet (repo might be empty)"
    cd ..
else
    echo "Cloning fresh copy..."
    gh repo clone "$GITHUB_USER/$TARGET_REPO" 2>/dev/null || {
        echo -e "${RED}❌ Failed to clone $TARGET_REPO${NC}"
        exit 1
    }
fi

cd "$TARGET_REPO"

# Check if repo is empty and initialize if needed
if [ ! -f "README.md" ] && [ -z "$(git ls-remote origin 2>/dev/null)" ]; then
    echo -e "${YELLOW}📝 Initializing empty repository with README...${NC}"
    echo "# Learning Artifacts

Consolidated repository for learning materials, experiments, and prototypes organized by topic.

## Structure

- **frontend/**: Frontend frameworks and technologies (Angular, React, Astro, Vanilla JS)
- **ai-ml/**: AI/ML projects and Streamlit applications
- **utilities/**: Utility tools and helper projects
- **experiments/**: Various experimental projects

## Organization

Each subdirectory contains projects organized by technology or topic, with a \`SOURCE.md\` file indicating the original repository source.
" > README.md
    git add README.md
    git commit -m "Initial commit: Setup learning-artifacts repository structure"
    git push -u origin main 2>/dev/null || git push -u origin master
fi

# Create directory structure
echo -e "${YELLOW}📁 Setting up directory structure...${NC}"
mkdir -p frontend/{angular,react,astro,vanilla-js}
mkdir -p ai-ml/{streamlit-apps,notebooks,datasets}
mkdir -p utilities
mkdir -p experiments

cd ..

# Define migration mappings: source_repo:target_path:subdirectory
declare -a MIGRATIONS=(
    # Frontend - Angular
    "Angular-Directives:frontend/angular:Angular-Directives"
    "AngularJsMasterGrid:frontend/angular:AngularJsMasterGrid"
    "AngularJsMvcGrid:frontend/angular:AngularJsMvcGrid"
    "ng-material-app:frontend/angular:ng-material-app"
    
    # Frontend - Other
    "frontend-challenge:frontend/vanilla-js:frontend-challenge"
    "js-cycle:frontend/vanilla-js:js-cycle"
    "astro-crafted-experience:frontend/astro:astro-crafted-experience"
    "box-portal-demo:frontend/vanilla-js:box-portal-demo"
    
    # AI/ML
    "bank-marketing-ml-streamlit:ai-ml/streamlit-apps:bank-marketing-ml"
    
    # Utilities
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

# Step 3: Migrate repos
echo -e "${YELLOW}🔄 Migrating repositories...${NC}"

for migration in "${MIGRATIONS[@]}"; do
    IFS=':' read -r source_repo target_path sub_dir <<< "$migration"
    
    echo -e "${BLUE}Processing: $source_repo${NC}"
    
    # Clone the source repo
    if [ -d "$source_repo" ]; then
        echo "  Updating $source_repo..."
        cd "$source_repo"
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
        cd ..
    else
        echo "  Cloning $source_repo..."
        gh repo clone "$GITHUB_USER/$source_repo" 2>/dev/null || {
            echo -e "${RED}❌ Failed to clone $source_repo${NC}"
            echo "Failed: $source_repo" >> "$LOG_FILE"
            continue
        }
    fi
    
    # Create target directory
    target_full_path="$TARGET_REPO/$target_path/$sub_dir"
    mkdir -p "$target_full_path"
    
    # Copy all files (skip .git during copy)
    echo "  Merging content..."
    
    # Copy regular files
    cp -r "$source_repo"/* "$target_full_path/" 2>/dev/null || true
    
    # Copy hidden files except .git
    find "$source_repo" -maxdepth 1 -type f -name ".*" ! -name ".git" -exec cp {} "$target_full_path/" \; 2>/dev/null || true
    
    # Remove all .git directories recursively
    find "$target_full_path" -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true
    
    # Add attribution file
    cat > "$target_full_path/SOURCE.md" << EOF
# Source: $source_repo

This folder was migrated from the repository: [\`$GITHUB_USER/$source_repo\`](https://github.com/$GITHUB_USER/$source_repo)

**Original Repository:** https://github.com/$GITHUB_USER/$source_repo

All content has been consolidated into the learning-artifacts repository for better organization.
EOF
    
    echo -e "${GREEN}✅ Done${NC}"
    echo "Success: $source_repo → $target_path/$sub_dir" >> "$LOG_FILE"
done

# Step 4: Clean up any remaining .git directories
echo -e "${YELLOW}🧹 Final cleanup: removing embedded git repositories...${NC}"
find "$TARGET_REPO" -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true

# Step 5: Commit to target repo
echo -e "${YELLOW}💾 Committing and pushing changes...${NC}"
cd "$TARGET_REPO"

git add -A

# Check if there are changes to commit
if git diff --cached --quiet; then
    echo "No changes to commit"
else
    git commit -m "🚀 Consolidate repositories: Migrate learning projects into organized structure

Migrated repos:
- Frontend: Angular projects, challenges, experiments (4 repos)
- AI/ML: Streamlit applications (1 repo)
- Utilities: Various utility projects (8 repos)
- Experiments: Other learning projects (5 repos)

This consolidation organizes all learning materials into a single repository with logical subdirectories for easier maintenance and discovery."

    # Push to remote
    echo "Pushing to remote..."
    git push origin main 2>/dev/null || git push origin master || {
        echo -e "${RED}❌ Failed to push changes${NC}"
        exit 1
    }
fi

cd ..

echo -e "${GREEN}✅ Changes committed and pushed${NC}"

# Step 6: Summary and cleanup instructions
echo -e "${BLUE}📊 Migration Summary${NC}"
echo "=========================="
cat "$LOG_FILE"
echo "=========================="

echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. ✅ Verify all content at: https://github.com/$GITHUB_USER/$TARGET_REPO"
echo ""
echo "2. Delete old repositories when ready:"
echo ""
for migration in "${MIGRATIONS[@]}"; do
    IFS=':' read -r source_repo _ _ <<< "$migration"
    echo "   gh repo delete $GITHUB_USER/$source_repo --confirm"
done
echo ""
echo "3. Clean up local workspace:"
echo "   cd .. && rm -rf $WORK_DIR"

echo -e "${GREEN}✨ Migration complete!${NC}"
