Bulk Redactor
=============

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0) ![This script was last tested in Nuix 7.8](https://img.shields.io/badge/Script%20Tested%20in%20Nuix-7.8-green.svg)

View the GitHub project [here](https://github.com/Nuix/Bulk-Redactor) or download the latest release [here](https://github.com/Nuix/Bulk-Redactor/releases).

# Overview

As of Nuix 7.8.0.10, the API does not offer functionality to perform bulk redactions, something that is present in the user interface.  Using functionality built in to [SuperUtilities.jar](https://github.com/Nuix/SuperUtilities) this script provides the ability to generate bulk redactions based on:
- Regular expressions
- Terms and Phrases
- Named Entity matches

The script leverages Aspose (distributed with Nuix) to search the content of PDFs for text matches.  The coordinates of each match are converted to a form which can then be used to apply redactions to items in your Nuix case.  Since Aposes needs a PDF file to work from for the searching, this script will export temporary PDF files for each item processed.

# Getting Started

## Setup

Begin by downloading the latest release of this code.  Extract the contents of the archive into your Nuix scripts directory.  In Windows the script directory is likely going to be either of the following:

- `%appdata%\Nuix\Scripts` - User level script directory
- `%programdata%\Nuix\Scripts` - System level script directory

# Usage

Begin by selecting some items in the results view, then run the script.  A settings dialog will be presented.

## General Settings Tab

On this tab you select either the name of an existing markup set (if any already exist in the case) or provide the name of a new markup set to be created by the script.  This markup set will be where redactions (markups) will be added to.

On this tab you also provide a temp directory.  This temp directory is where the script will export PDF files which will be used by Aspose for determining text position data.

## Regular Expressions Tab

On this tab you may provide regular expressions which will be used to locate text to be redacted.

## Terms & Phrases Tab

On this tab you may provide single terms or entire phrases.  All text searches are submit to Aspose as regular expressions.  Terms and phrases provided on this tab are converted to regular expressions internally by the script using the following steps:

1. The given term or phrase is split into tokens on whitespace.
2. With each token:
	1. The following characters are escaped so they will become literal matches: `\{}.^$()-*?|<>[]`
	2. Each character which is determined to be a letter, as determined by calling [Character.isLetter](https://docs.oracle.com/javase/8/docs/api/java/lang/Character.html#isLetter-char-), is converted to match both upper and lower case versions of that letter.  For example `Cat` becomes `[Cc][Aa][Tt]`.  This is because, while the Aspose API accepts regular expressions, there does not seem to be a way to tell it to locate them in a case insensitive manner.
3. Individual tokens are then concatenated back together, joined by `\s+` (match 1 or more whitespace characters).
4. Finally, concatenated tokens are then surrounded by `\b` (anchor to word boundary).

Here are some example input terms/phrases and the resulting expressions they yield.

| Input | Resulting Expression |
|-------|----------------------|
| `C:\ImportantData\Spreadsheet.xlsx` | `\b[Cc]:\\[Ii][Mm][Pp][Oo][Rr][Tt][Aa][Nn][Tt][Dd][Aa][Tt][Aa]\\[Ss][Pp][Rr][Ee][Aa][Dd][Ss][Hh][Ee][Ee][Tt]\.[Xx][Ll][Ss][Xx]\b` |
| `randomized fake data` | `\b[Rr][Aa][Nn][Dd][Oo][Mm][Ii][Zz][Ee][Dd]\s+[Ff][Aa][Kk][Ee]\s+[Dd][Aa][Tt][Aa]\b` |
| `The Lazy Cat` | `\b[Tt][Hh][Ee]\s+[Ll][Aa][Zz][Yy]\s+[Cc][Aa][Tt]\b` |
| `[REPLY]` | `\b\[[Rr][Ee][Pp][Ll][Yy]\]\b` |
| `1-555-555-1234` | `1\-555\-555\-1234` |

## Named Entities Tab

On this tab you may select named entites you wish to have the matches of redacted.  For each selected named entity type and a given item, all the named entity match values will be collected and then converted to expressions using the workflow outlined above for terms and phrases.

# Additional Notes

To find text, the script makes use of the Aspose class [TextFragmentAbsorber](https://apireference.aspose.com/java/pdf/com.aspose.pdf/TextFragmentAbsorber).  This in turn provides a series of [TextFragment](https://apireference.aspose.com/java/pdf/com.aspose.pdf/TextFragment) objects.  Each TextFragment contains information about the text matched as well as a bounding box that encompasses that text.  If the matched text wraps to a new line in the PDF, the bounding box provided would cover the entirety of both lines.

The script deals with this by going deeper and inspecting each [TextSegment](https://apireference.aspose.com/java/pdf/com.aspose.pdf/TextSegment) in the fragment (essentially each individual character).  The script then groups TextSegments by the line they are on, as determined by the value of the bounding box lower left Y coordinate rounded to 6 decimal places.  Then within each per-line group, TextSegments are ordered by the lower left X coordinate.  Multiple TextSegments on a given line are then converted into a single bounding box, which is then used to generate the appropriate redaction in Nuix.

This extra logic means:
- Multi-term phrase matches which may have some matched terms on a consecutive line, due to word wrapping, should result in more accurate redactions in Nuix.
- Multiple terms matched by a phrase on a given line should result in a single redaction instead of a separate redaction for each term.

It is **highly recommended** that you review all redactions generated by this script, no automated process is perfect!  It is possible that the above mentioned logic could yield odd redactions when the quality of the source PDF is less uniform (think image which has been OCR'ed).

# Cloning this Repository

This script relies on code from [Nx](https://github.com/Nuix/Nx) to present a settings dialog and progress dialog.  This JAR file is not included in the repository (although it is included in release downloads).  If you clone this repository, you will also want to obtain a copy of Nx.jar by either:
1. Building it from [the source](https://github.com/Nuix/Nx)
2. Downloading an already built JAR file from the [Nx releases](https://github.com/Nuix/Nx/releases)

Once you have a copy of Nx.jar, make sure to include it in the same directory as the script.

This script also relies on code from [SuperUtilities](https://github.com/Nuix/SuperUtilities), which contains the code for performing the redactions.  This JAR file is not included in the repository (although it is included in release downloads).  If you clone this repository, you will also want to obtain a copy of SuperUtilities.jar by either:
1. Building it from [the source](https://github.com/Nuix/SuperUtilities)
2. Downloading an already built JAR file from the [Nx releases](https://github.com/Nuix/SuperUtilities/releases)

Once you also have a copy of SuperUtilities.jar, make sure to include it in the same directory as the script.

# License

```
Copyright 2019 Nuix

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```