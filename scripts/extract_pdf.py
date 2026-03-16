#!/usr/bin/env python3
"""
PDF Text Extraction Script
==========================
Extracts text content from PDF files in docs/protocol_spec/ directory.
Useful for analyzing protocol specifications.

Usage:
    python3 scripts/extract_pdf.py [OPTIONS]

Examples:
    python3 scripts/extract_pdf.py                    # Extract all PDFs
    python3 scripts/extract_pdf.py -l                 # List PDFs only
    python3 scripts/extract_pdf.py -p 1-10            # Extract pages 1-10
    python3 scripts/extract_pdf.py -o output.txt      # Save to file
    python3 scripts/extract_pdf.py -k "credit"        # Search keyword
"""

import argparse
import os
import sys
from pathlib import Path
from typing import List, Optional

try:
    from pypdf import PdfReader
except ImportError:
    print("Error: pypdf not installed.")
    print("Install with: pip install pypdf")
    sys.exit(1)


# Configuration
DEFAULT_PDF_DIR = Path("docs/protocol_spec")
DEFAULT_OUTPUT_DIR = Path("docs/protocol_spec/extracted")


def find_pdfs(pdf_dir: Path) -> List[Path]:
    """Find all PDF files in the specified directory."""
    if not pdf_dir.exists():
        print(f"Error: Directory not found: {pdf_dir}")
        sys.exit(1)
    
    pdf_files = list(pdf_dir.glob("*.pdf"))
    if not pdf_files:
        print(f"No PDF files found in {pdf_dir}")
        sys.exit(1)
    
    return sorted(pdf_files)


def extract_pdf(
    pdf_path: Path,
    pages: Optional[str] = None,
    keyword: Optional[str] = None,
    verbose: bool = False
) -> str:
    """
    Extract text from a PDF file.
    
    Args:
        pdf_path: Path to the PDF file
        pages: Page range (e.g., "1-10" or "1,3,5")
        keyword: Filter lines containing this keyword
        verbose: Print progress
    
    Returns:
        Extracted text content
    """
    try:
        reader = PdfReader(str(pdf_path))
    except Exception as e:
        print(f"Error reading {pdf_path.name}: {e}")
        return ""
    
    num_pages = len(reader.pages)
    
    # Parse page range
    page_indices = []
    if pages:
        for part in pages.split(","):
            if "-" in part:
                start, end = part.split("-")
                page_indices.extend(range(int(start) - 1, int(end)))
            else:
                page_indices.append(int(part) - 1)
    else:
        page_indices = list(range(num_pages))
    
    # Filter valid page indices
    page_indices = [i for i in page_indices if 0 <= i < num_pages]
    
    if verbose:
        print(f"  Extracting {len(page_indices)} pages from {num_pages} total...")
    
    text_lines = []
    
    for idx in page_indices:
        try:
            page = reader.pages[idx]
            text = page.extract_text()
            
            if text:
                if keyword:
                    # Filter lines containing keyword (case-insensitive)
                    for line in text.split("\n"):
                        if keyword.lower() in line.lower():
                            text_lines.append(f"[Page {idx + 1}] {line}")
                else:
                    text_lines.append(f"--- Page {idx + 1} ---")
                    text_lines.append(text)
        except Exception as e:
            print(f"  Warning: Error extracting page {idx + 1}: {e}")
    
    return "\n".join(text_lines)


def list_pdfs(pdf_dir: Path) -> None:
    """List all PDF files with basic info."""
    pdf_files = find_pdfs(pdf_dir)
    
    print("\n" + "=" * 70)
    print("PDF Files in", pdf_dir)
    print("=" * 70)
    
    for pdf_path in pdf_files:
        try:
            reader = PdfReader(str(pdf_path))
            num_pages = len(reader.pages)
            # Try to get title from metadata
            metadata = reader.metadata
            title = metadata.get("/Title", "") if metadata else ""
            
            print(f"\n{pdf_path.name}")
            print(f"  Pages: {num_pages}")
            if title:
                print(f"  Title: {title}")
        except Exception as e:
            print(f"\n{pdf_path.name} - Error: {e}")
    
    print("\n" + "=" * 70)


def main():
    parser = argparse.ArgumentParser(
        description="Extract text from PDF protocol specification files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument(
        "-d", "--dir",
        type=Path,
        default=DEFAULT_PDF_DIR,
        help=f"PDF directory (default: {DEFAULT_PDF_DIR})"
    )
    
    parser.add_argument(
        "-l", "--list",
        action="store_true",
        help="List PDF files only"
    )
    
    parser.add_argument(
        "-p", "--pages",
        type=str,
        help="Page range to extract (e.g., '1-10' or '1,3,5')"
    )
    
    parser.add_argument(
        "-o", "--output",
        type=str,
        help="Output file (default: print to stdout)"
    )
    
    parser.add_argument(
        "-k", "--keyword",
        type=str,
        help="Extract only lines containing this keyword"
    )
    
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Verbose output"
    )
    
    parser.add_argument(
        "--all",
        action="store_true",
        help="Extract all pages (default if no other options)"
    )
    
    args = parser.parse_args()
    
    # List mode
    if args.list:
        list_pdfs(args.dir)
        return
    
    # Find PDFs
    pdf_files = find_pdfs(args.dir)
    
    if args.verbose:
        print(f"Found {len(pdf_files)} PDF files")
    
    # Extract from each PDF
    all_text = []
    
    for pdf_path in pdf_files:
        if args.verbose:
            print(f"\nProcessing: {pdf_path.name}")
        
        text = extract_pdf(
            pdf_path,
            pages=args.pages,
            keyword=args.keyword,
            verbose=args.verbose
        )
        
        if text:
            all_text.append(f"\n{'=' * 70}\n")
            all_text.append(f"FILE: {pdf_path.name}\n")
            all_text.append(f"{'=' * 70}\n")
            all_text.append(text)
    
    result = "\n".join(all_text)
    
    # Output
    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(result)
        print(f"\nOutput saved to: {output_path}")
    else:
        print(result)
    
    if args.keyword:
        print(f"\n[Filtered by keyword: '{args.keyword}']")


if __name__ == "__main__":
    main()
