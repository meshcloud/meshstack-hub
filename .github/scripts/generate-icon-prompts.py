#!/usr/bin/env python3
"""
Generate icon prompts for building blocks missing logo.png files.
Parses README.md frontmatter and creates AI image generation prompts.
"""

import os
import sys
import yaml
import json
from pathlib import Path

PLATFORM_COLORS = {
    "aws": {
        "primary": "#FF9900",
        "secondary": "#232F3E",
        "accent": "#7FBA00",
        "name": "AWS colors: orange (#FF9900), dark blue (#232F3E), and lime green (#7FBA00)"
    },
    "azure": {
        "primary": "#0078D4",
        "secondary": "#00BCF2",
        "accent": "#50E6FF",
        "name": "Azure colors: blue (#0078D4), cyan (#00BCF2), and light blue (#50E6FF)"
    },
    "aks": {
        "primary": "#326CE5",
        "secondary": "#0078D4",
        "accent": "#00BCF2",
        "name": "Kubernetes/Azure colors: blue (#326CE5), Azure blue (#0078D4), and cyan (#00BCF2)"
    },
    "azuredevops": {
        "primary": "#0078D4",
        "secondary": "#00BCF2",
        "accent": "#005A9E",
        "name": "Azure DevOps colors: blue (#0078D4), teal (#00BCF2), and dark blue (#005A9E)"
    },
    "gcp": {
        "primary": "#4285F4",
        "secondary": "#EA4335",
        "accent": "#FBBC04",
        "name": "Google colors: blue (#4285F4), red (#EA4335), yellow (#FBBC04), and green (#34A853)"
    },
    "github": {
        "primary": "#6e5494",
        "secondary": "#24292e",
        "accent": "#8b5cf6",
        "name": "GitHub colors: purple (#6e5494), dark gray (#24292e), and bright purple (#8b5cf6)"
    },
    "ionos": {
        "primary": "#003D7A",
        "secondary": "#FF6600",
        "accent": "#0096D6",
        "name": "IONOS colors: blue (#003D7A), orange (#FF6600), and light blue (#0096D6)"
    },
    "kubernetes": {
        "primary": "#326CE5",
        "secondary": "#00D3E0",
        "accent": "#7AB8FF",
        "name": "Kubernetes colors: blue (#326CE5), cyan (#00D3E0), and light blue (#7AB8FF)"
    },
    "sapbtp": {
        "primary": "#0070AD",
        "secondary": "#F0AB00",
        "accent": "#0078D4",
        "name": "SAP colors: blue (#0070AD), gold (#F0AB00), and light blue (#0078D4)"
    },
    "stackit": {
        "primary": "#00A859",
        "secondary": "#007A3D",
        "accent": "#7FBA00",
        "name": "STACKIT colors: green (#00A859), dark green (#007A3D), and lime (#7FBA00)"
    }
}


def parse_readme_frontmatter(readme_path):
    """Extract YAML frontmatter from README.md"""
    with open(readme_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if not content.startswith('---'):
        return None
    
    # Extract frontmatter between --- delimiters
    parts = content.split('---', 2)
    if len(parts) < 3:
        return None
    
    try:
        frontmatter = yaml.safe_load(parts[1])
        return frontmatter
    except yaml.YAMLError:
        return None


def get_platform_from_frontmatter(frontmatter):
    """Get the primary platform from supportedPlatforms list"""
    platforms = frontmatter.get('supportedPlatforms', [])
    if not platforms:
        return None
    return platforms[0]  # Use first platform


def generate_icon_prompt(name, platform, description):
    """Generate an AI image generation prompt for an icon"""
    platform_colors = PLATFORM_COLORS.get(platform)
    
    if not platform_colors:
        # Fallback to generic bright colors
        color_scheme = "bright, vibrant colors"
    else:
        color_scheme = platform_colors["name"]
    
    # Clean up description
    clean_description = description.strip().replace('\n', ' ')
    
    # Generate AI prompt
    ai_prompt = f"""Create a professional flat design icon for the meshcloud Building Block ecosystem.

Purpose: {clean_description}

Visual Style:
- Plain white background (#FFFFFF) for easy removal in post-processing
- Background will be converted to transparent (see post-processing steps)
- Use meshcloud blue (#2563eb) as primary color
- Use {color_scheme} as accent colors
- Maximum 2-3 colors total
- Simple geometric shapes with clean lines
- Flat design (no gradients, shadows, or 3D effects)
- Minimalist, modern appearance

Composition:
- Square centered layout (NOT horizontal)
- Icon fills the entire canvas edge-to-edge (100% of area)
- No padding or margins around the icon
- Symmetrical arrangement
- Platform-appropriate symbol for {platform.upper()} (e.g., cloud, container, database, server, etc.)

Style: Enterprise professional, instantly recognizable at small sizes, similar to app icons or logos.
Dimensions: 800x800 pixels"""
    
    # Generate post-processing instructions
    post_processing = """**Step 1: Remove white background with GIMP (free)**

a) Open image in GIMP
b) Right-click layer → "Add Alpha Channel"
c) Tools → "Select by Color" (Shift+O)
d) Click white background
e) Press Delete key
f) File → Export As → logo.png
g) Set Compression level to 9 → Export

**Step 2: Resize to 800x800 pixels if needed**

- GIMP: Image → Scale Image → 800x800px
- Or use any image editor

**Step 3: Compress with pngquant (free command line tool)**

- Install: `brew install pngquant` (Mac) or `apt install pngquant` (Linux)
- Run: `pngquant --quality=20-30 logo.png --ext .png --force`
- This reduces file size by 60-80% while maintaining quality

**Target specs:** 800x800px PNG with transparent background, under 100KB"""
    
    return {
        'ai_prompt': ai_prompt,
        'post_processing': post_processing
    }

def find_missing_logos(modules_dir):
    """Find all buildingblock directories missing logo.png"""
    missing = []
    
    for root, dirs, files in os.walk(modules_dir):
        if 'buildingblock' in root:
            buildingblock_path = Path(root)
            readme_path = buildingblock_path / 'README.md'
            logo_path = buildingblock_path / 'logo.png'
            
            if readme_path.exists() and not logo_path.exists():
                frontmatter = parse_readme_frontmatter(readme_path)
                if frontmatter:
                    platform = get_platform_from_frontmatter(frontmatter)
                    name = frontmatter.get('name', 'Unknown')
                    description = frontmatter.get('description', '')
                    
                    # Get relative path from modules directory
                    rel_path = buildingblock_path.relative_to(modules_dir)
                    
                    missing.append({
                        'path': str(rel_path),
                        'name': name,
                        'platform': platform,
                        'description': description,
                        'readme_path': str(readme_path),
                        'logo_path': str(logo_path)
                    })
    
    return missing

def main():
    # Get modules directory
    repo_root = Path(__file__).parent.parent.parent
    modules_dir = repo_root / 'modules'
    
    if not modules_dir.exists():
        print(f"ERROR: Modules directory not found: {modules_dir}", file=sys.stderr)
        sys.exit(1)
    
    # Find missing logos
    missing_logos = find_missing_logos(modules_dir)
    
    # Generate prompts for each missing logo
    results = []
    for item in missing_logos:
        prompt_data = generate_icon_prompt(
            item['name'],
            item['platform'] or 'generic',
            item['description']
        )
        
        results.append({
            'name': item['name'],
            'platform': item['platform'],
            'path': item['path'],
            'logo_path': item['logo_path'],
            'ai_prompt': prompt_data['ai_prompt'],
            'post_processing': prompt_data['post_processing']
        })
    
    # Output as JSON for GitHub Action to consume
    print(json.dumps(results, indent=2))

if __name__ == '__main__':
    main()
