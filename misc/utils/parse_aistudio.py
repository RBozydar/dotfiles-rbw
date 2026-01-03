#!/usr/bin/env python3
"""
Parse Google AI Studio conversation exports into clean Markdown and JSON.

Usage:
    parse_aistudio.py "Conversation Name"
    parse_aistudio.py "Conversation Name" --input-dir /other/path
    parse_aistudio.py "Conversation Name" --output-dir ~/Downloads
    parse_aistudio.py "Conversation Name" --include-settings
    parse_aistudio.py "Conversation Name" --format md
"""

import argparse
import json
import copy
from pathlib import Path

DEFAULT_INPUT_DIR = Path.home() / "Library/CloudStorage/GoogleDrive-wasilewski.robert@gmail.com/My Drive/Google AI Studio"


def load_aistudio_file(path: Path) -> dict:
    """Load and validate a Google AI Studio export file."""
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    if 'chunkedPrompt' not in data or 'chunks' not in data.get('chunkedPrompt', {}):
        raise ValueError("Invalid Google AI Studio file: missing chunkedPrompt.chunks")

    return data


def clean_json(data: dict) -> dict:
    """
    Clean the JSON by:
    - Removing thoughtSignature fields
    - Merging fragmented parts[].text into single text field
    """
    cleaned = copy.deepcopy(data)

    for chunk in cleaned.get('chunkedPrompt', {}).get('chunks', []):
        # Remove thoughtSignature from parts
        if 'parts' in chunk:
            for part in chunk['parts']:
                if 'thoughtSignature' in part:
                    del part['thoughtSignature']

            # Merge parts text if not already in main text
            # (parts are often streaming fragments)
            if chunk.get('parts') and not chunk.get('text'):
                merged_text = ''.join(p.get('text', '') for p in chunk['parts'])
                chunk['text'] = merged_text

        # Clean up empty/redundant fields
        if 'parts' in chunk:
            # Simplify parts to just text and thought flag
            chunk['parts'] = [
                {k: v for k, v in p.items() if k in ('text', 'thought')}
                for p in chunk['parts']
            ]

    return cleaned


def to_markdown(data: dict, include_settings: bool = False) -> str:
    """Convert to formatted markdown with collapsible thinking blocks."""
    lines = []

    # Optional settings header
    if include_settings and 'runSettings' in data:
        settings = data['runSettings']
        lines.append("# Conversation Export")
        lines.append("")
        lines.append("<details>")
        lines.append("<summary>Model Settings</summary>")
        lines.append("")
        lines.append(f"- **Model**: {settings.get('model', 'unknown')}")
        lines.append(f"- **Temperature**: {settings.get('temperature', 'N/A')}")
        lines.append(f"- **Top P**: {settings.get('topP', 'N/A')}")
        lines.append(f"- **Top K**: {settings.get('topK', 'N/A')}")
        lines.append(f"- **Max Output Tokens**: {settings.get('maxOutputTokens', 'N/A')}")
        if settings.get('thinkingLevel'):
            lines.append(f"- **Thinking Level**: {settings.get('thinkingLevel')}")
        lines.append("")
        lines.append("</details>")
        lines.append("")
        lines.append("---")
        lines.append("")

    # Process conversation chunks
    for chunk in data.get('chunkedPrompt', {}).get('chunks', []):
        role = chunk.get('role', 'unknown')
        text = chunk.get('text', '')
        is_thought = chunk.get('isThought', False)

        # Format role header
        if role == 'user':
            lines.append("## User")
        elif role == 'model':
            if is_thought:
                lines.append("<details>")
                lines.append("<summary><strong>Model Thinking</strong></summary>")
                lines.append("")
            else:
                lines.append("## Assistant")
        else:
            lines.append(f"## {role.title()}")

        lines.append("")

        # Add content
        if text:
            lines.append(text)

        # Close thinking block if needed
        if role == 'model' and is_thought:
            lines.append("")
            lines.append("</details>")

        lines.append("")

    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(
        description='Parse Google AI Studio conversation exports'
    )
    parser.add_argument(
        'input_file',
        type=str,
        help='Input file name (looked up in input-dir)'
    )
    parser.add_argument(
        '--input-dir', '-i',
        type=Path,
        default=DEFAULT_INPUT_DIR,
        help=f'Input directory (default: {DEFAULT_INPUT_DIR})'
    )
    parser.add_argument(
        '--output-dir', '-o',
        type=Path,
        default=Path.cwd(),
        help='Output directory (default: current working directory)'
    )
    parser.add_argument(
        '--format', '-f',
        choices=['md', 'json', 'both'],
        default='both',
        help='Output format (default: both)'
    )
    parser.add_argument(
        '--include-settings',
        action='store_true',
        help='Include model settings in markdown output'
    )

    args = parser.parse_args()

    # Resolve input path
    input_path = (args.input_dir / args.input_file).resolve()
    if not input_path.exists():
        print(f"Error: File not found: {input_path}")
        return 1

    data = load_aistudio_file(input_path)

    # Ensure output directory exists
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    # Base name for outputs
    base_name = input_path.stem

    # Generate outputs
    if args.format in ('json', 'both'):
        cleaned = clean_json(data)
        json_path = output_dir / f"{base_name}_clean.json"
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(cleaned, f, indent=2, ensure_ascii=False)
        print(f"Created: {json_path}")

    if args.format in ('md', 'both'):
        markdown = to_markdown(data, include_settings=args.include_settings)
        md_path = output_dir / f"{base_name}.md"
        with open(md_path, 'w', encoding='utf-8') as f:
            f.write(markdown)
        print(f"Created: {md_path}")

    return 0


if __name__ == '__main__':
    exit(main())
