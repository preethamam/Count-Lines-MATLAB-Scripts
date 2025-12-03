function countLines(inputPath, fileTypes, ignoreFiles, saveDir)
%COUNTLINES Recursively count code, comment, and blank lines.
%
% Syntax:
%   countLines(inputPath)
%   countLines(inputPath, fileTypes)
%   countLines(inputPath, fileTypes, ignoreFiles)
%   countLines(inputPath, fileTypes, ignoreFiles, saveDir)
%
% Description:
%   Recursively searches the specified folder (or accepts a cell array of
%   files) and counts the number of code lines, comment lines and blank
%   lines for files with the provided extensions. Results are written to a
%   text file named 'lineCount.txt' in saveDir.
%
% Inputs:
%   inputPath   - (char | string | cell) Folder path to search recursively
%                 or a cell array of file paths to analyze.
%   fileTypes   - (cell) Cell array of file extensions to include, e.g.
%                 {'.m', '.cpp'}. Defaults to {'.m'}.
%   ignoreFiles - (cell) Cell array of base filenames (name + ext) to
%                 ignore, e.g. {'scratch.m'}. Defaults to {}.
%   saveDir     - (char | string) Directory to write 'lineCount.txt'.
%                 Defaults to pwd.
%
% Outputs:
%   Writes 'lineCount.txt' to saveDir with per-file counts and grand totals.
%   No return variables.
%
% Examples:
%   countLines('C:\proj', {'.m','.cpp'}, {'ignore.m'}, 'C:\out')
%   countLines({'file1.m','file2.cpp'}, {'.m','.cpp'})
%
% Limitations / Heuristics:
%   - A line that starts with '%' (MATLAB) or '//' (C/C++) is treated as a
%     comment line.
%   - Block comments using /* ... */ are tracked across lines.
%   - Inline comments on the same line as code are treated as code lines.
%   - This is a heuristic approach and may misclassify complex language cases.
%
% See also: parseFile
%
% Author: (project)
% Date: (auto)
%
% -------------------------------------------------------------------------

% --- argument validation ---
arguments
    % inputPath may be a folder path (char/string) or a cell array of files.
    inputPath
    fileTypes {mustBeA(fileTypes, 'cell')} = {'.m'}
    ignoreFiles {mustBeA(ignoreFiles, 'cell')} = {}
    saveDir {mustBeTextScalar} = pwd
end

% Validate inputPath type
if ~(ischar(inputPath) || isstring(inputPath) || iscell(inputPath))
    error('countLines:InvalidInput', 'inputPath must be a folder path (char/string) or a cell array of files.');
end

% Validate fileTypes contents
if ~all(cellfun(@(e) (ischar(e) || isstring(e)) && startsWith(char(e),'.'), fileTypes))
    error('countLines:InvalidFileTypes', 'fileTypes must be a cell array of extensions, e.g. {''.m'',''.cpp''}.');
end

% Validate ignoreFiles contents
if ~all(cellfun(@(f) ischar(f) || isstring(f), ignoreFiles))
    error('countLines:InvalidIgnoreFiles', 'ignoreFiles must be a cell array of filenames (char or string).');
end

% Ensure saveDir exists (if provided as string)
saveDir = char(saveDir);
if ~isfolder(saveDir)
    error('countLines:InvalidSaveDir', 'saveDir must be an existing folder.');
end

% --- build file list ---
if ischar(inputPath) || isstring(inputPath)
    inputPath = char(inputPath);

    if isfolder(inputPath)
        files = {};
        for k = 1:numel(fileTypes)
            pattern = fullfile(inputPath, '**', ['*' fileTypes{k}]);
            d = dir(pattern);
            files = [files; fullfile({d.folder}', {d.name}')];
        end
    else
        files = {inputPath};
    end

elseif iscell(inputPath)
    files = inputPath(:);
else
    error('inputPath must be a folder or cell array of files.');
end

% --- remove ignored files ---
[~, baseNames, extNames] = cellfun(@fileparts, files, 'UniformOutput', false);
fullNames = strcat(baseNames, extNames);
maskIgnore = ismember(fullNames, ignoreFiles);
files(maskIgnore) = [];

% --- counters ---
nFiles = numel(files);
codeCount   = zeros(nFiles,1);
commCount   = zeros(nFiles,1);
blankCount  = zeros(nFiles,1);
totalCount  = zeros(nFiles,1);

% --- parse each file ---
for i = 1:nFiles
    [codeCount(i), commCount(i), blankCount(i), totalCount(i)] = ...
        parseFile(files{i});
end

% --- write output ---
outFile = fullfile(saveDir, 'lineCount.txt');
fid = fopen(outFile, 'w');

fprintf(fid, "File : Code | Comments | Blank | Total\n");
fprintf(fid, "------------------------------------------------------\n");

for i = 1:nFiles
    fprintf(fid, "%s : %d | %d | %d | %d\n", ...
        files{i}, codeCount(i), commCount(i), blankCount(i), totalCount(i));
end

fprintf(fid, "\nGrand Totals:\n");
fprintf(fid, "Code     : %d\n", sum(codeCount));
fprintf(fid, "Comments : %d\n", sum(commCount));
fprintf(fid, "Blank    : %d\n", sum(blankCount));
fprintf(fid, "Total    : %d\n", sum(totalCount));

fclose(fid);

fprintf("lineCount.txt created.\n");
end

% =====================================================================
function [code, comments, blank, total] = parseFile(fname)
%PARSEFILE Parse a single file and classify lines as code, comment or blank.
%
% Syntax:
%   [code, comments, blank, total] = parseFile(fname)
%
% Description:
%   Reads a text file and classifies each line as code, comment, or blank
%   using simple heuristics. Supports MATLAB '%' comments, C/C++ '//' single
%   line comments, and '/* ... */' block comments.
%
% Inputs:
%   fname - (char | string) Path to the file to parse.
%
% Outputs:
%   code     - Number of code lines detected (numeric scalar).
%   comments - Number of comment lines detected (numeric scalar).
%   blank    - Number of blank lines detected (numeric scalar).
%   total    - Total number of lines in the file (numeric scalar).
%
% Examples:
%   [c,com,b,t] = parseFile('myfile.m')
%
% Notes:
%   - Inline comments on a line with code are counted as code lines.
%   - This function uses a heuristic approach and may misclassify some lines.
%
% -------------------------------------------------------------------------

% --- argument validation ---
arguments
    fname {mustBeTextScalar}
end
fname = char(fname);

% If file cannot be read, return zeros (non-fatal to caller)
if ~isfile(fname)
    warning('parseFile:FileNotFound', 'File "%s" not found. Counts set to zero.', fname);
    code = 0; comments = 0; blank = 0; total = 0;
    return;
end

fid = fopen(fname, 'r');
if fid < 0
    warning('parseFile:OpenFailed', 'Unable to open file "%s". Counts set to zero.', fname);
    code = 0; comments = 0; blank = 0; total = 0;
    return;
end

lines = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);
lines = lines{1};
total = numel(lines);

code = 0; comments = 0; blank = 0;

inBlockComment = false;

for k = 1:total
    L = strtrim(lines{k});

    % --- blank line ---
    if isempty(L)
        blank = blank + 1;
        continue;
    end

    % --- MATLAB % comment ---
    if startsWith(L, '%')
        comments = comments + 1;
        continue;
    end

    % --- C/C++ single line comment ---
    if startsWith(L, '//')
        comments = comments + 1;
        continue;
    end

    % --- block comment begin ---
    if contains(L, '/*')
        comments = comments + 1;
        inBlockComment = true;
        if contains(L, '*/')
            inBlockComment = false;
        end
        continue;
    end

    % --- inside block comment ---
    if inBlockComment
        comments = comments + 1;
        if contains(L, '*/')
            inBlockComment = false;
        end
        continue;
    end

    % --- MATLAB block comment begin (%{) ---
    if contains(L, '%{')
        comments = comments + 1;
        inBlockComment = true;
        if contains(L, '%}')
            inBlockComment = false;
        end
        continue;
    end

    % --- inside MATLAB %{ ... %} block comment ---
    if inBlockComment
        comments = comments + 1;
        if contains(L, '%}')
            inBlockComment = false;
        end
        continue;
    end

    % --- mixed MATLAB inline comment (code + %) ---
    if contains(L, '%') && ~startsWith(L, '%')
        code = code + 1;
        comments = comments + 1;
        continue;
    end

    % --- mixed C/C++ inline comment (code + //) ---
    if contains(L, '//') && ~startsWith(L, '//')
        code = code + 1;
        comments = comments + 1;
        continue;
    end

    % --- otherwise: code line ---
    code = code + 1;
end
end
