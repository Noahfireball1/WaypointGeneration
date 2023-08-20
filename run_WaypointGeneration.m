%% Formatting
clc
clear
close all
format shortg

%% Add User Current Directories
projectRoot = fileparts(which(mfilename));
addpath(genpath(projectRoot))
dirs.config = append(projectRoot,filesep,'config',filesep);
dirs.src = append(projectRoot,filesep,'source',filesep);
dirs.data = append(projectRoot,filesep,'data',filesep);
dirs.output = append(projectRoot,filesep,'waypoints',filesep);

%% Select .kmz or .kml file to process
inputFile = uigetfile({'*.yaml'},'Select Input File',dirs.config);
inputFilePath = append(dirs.data,inputFile);

%% Process selected file
WG = WaypointGeneration(inputFilePath,dirs);


