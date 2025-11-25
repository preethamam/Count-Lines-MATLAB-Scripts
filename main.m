clear; close all; clc;
Start = tic;

%% Inputs
%--------------------------------------------------------------------------
inputPath = 'D:\OneDrive\Education Materials\Applications\Toolboxes\Matlab\My Functions\AutoPanoStitch\Procedural Program';
fileTypes = {'.m','.cpp'};
ignoreFiles = {'scrachPaper.m'};
saveDir = inputPath;

%% Count lines
countLines(inputPath, fileTypes, ignoreFiles, saveDir)

%% End parameters
%--------------------------------------------------------------------------
Runtime = toc(Start);
