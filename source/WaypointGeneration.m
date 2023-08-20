classdef WaypointGeneration < handle

    properties
        dataFile;
        alt = 1000;
        save = 1;
    end

    methods
        function obj = WaypointGeneration(inputFilePath,dirs)

            % Load selected yaml configuration file
            config = ReadYaml(inputFilePath);

            % Assign properties
            fileName = config.WaypointGeneration.kmlFile;
            obj.dataFile = append(dirs.data,fileName,'.kml');


            obj.alt = config.WaypointGeneration.altitude;
            obj.save = config.WaypointGeneration.save;

            % Process path and turn into waypoints
            kmlRaw = obj.kml2struct(obj.dataFile);
            waypoints = obj.process(kmlRaw);

            % Save waypoints to output directory
            if obj.save
                save(append(dirs.output,fileName,'.mat'),"waypoints")
            end
        end

        function waypoints = process(obj,kml)

            i = 1;
            count = 1;
            splLat = [];
            splLon = [];
            while i <= length(kml.latitude) && count <= length(kml.latitude) - 1
                [lat, lon] = obj.google_earth_spline(kml.latitude(count:count+1),kml.longitude(count:count+1));

                splLat = [splLat;lat];
                splLon = [splLon;lon];
                i = i+1;
                count = count + 1;
            end

            splLLA = [splLat,splLon,obj.alt*ones(length(splLon),1)];
            refLL = [kml.latitude(end) kml.longitude(end)];

            figure
            geoplot(splLat,splLon,LineWidth=2)
            hold on
            geoplot(refLL(1),refLL(2),'*r')
            geobasemap satellite

            waypoints = lla2flat(splLLA,refLL,0,0);
        end

    end
    methods (Access = private)

        function kmlStruct = kml2struct(~,kmlFile)

            [FID, msg] = fopen(kmlFile,'rt');

            if FID<0
                error(msg)
            end

            txt = fread(FID,'uint8=>char')';
            fclose(FID);

            expr = '<Placemark.+?>.+?</Placemark>';

            objectStrings = regexp(txt,expr,'match');

            Nos = length(objectStrings);

            kmlStruct = struct('geometry', 0,...
                'name', 0,...
                'description', 0,...
                'longitude', 0,...
                'latitude', 0,...
                'boundingBox', 0);

            for ii = 1:Nos
                % Find Object Name Field
                bucket = regexp(objectStrings{ii},'<name.*?>.+?</name>','match');
                if isempty(bucket)
                    name = 'undefined';
                else
                    % Clip off flags
                    name = regexprep(bucket{1},'<name.*?>\s*','');
                    name = regexprep(name,'\s*</name>','');
                end

                % Find Object Description Field
                bucket = regexp(objectStrings{ii},'<description.*?>.+?</description>','match');
                if isempty(bucket)
                    desc = '';
                else
                    % Clip off flags
                    desc = regexprep(bucket{1},'<description.*?>\s*','');
                    desc = regexprep(desc,'\s*</description>','');
                end

                geom = 0;
                % Identify Object Type
                if ~isempty(regexp(objectStrings{ii},'<Point', 'once'))
                    geom = 1;
                elseif ~isempty(regexp(objectStrings{ii},'<LineString', 'once'))
                    geom = 2;
                elseif ~isempty(regexp(objectStrings{ii},'<Polygon', 'once'))
                    geom = 3;
                end

                switch geom
                    case 1
                        geometry = 'Point';
                    case 2
                        geometry = 'Line';
                    case 3
                        geometry = 'Polygon';
                    otherwise
                        geometry = '';
                end

                % Find Coordinate Field
                bucket = regexp(objectStrings{ii},'<coordinates.*?>.+?</coordinates>','match');
                % Clip off flags
                coordStr = regexprep(bucket{1},'<coordinates.*?>(\s+)*','');
                coordStr = regexprep(coordStr,'(\s+)*</coordinates>','');
                % Split coordinate string by commas or white spaces, and convert string
                % to doubles
                coordMat = str2double(regexp(coordStr,'[,\s]+','split'));
                % Rearrange coordinates to form an x-by-3 matrix
                [m,n] = size(coordMat);
                coordMat = reshape(coordMat,3,m*n/3)';

                % define polygon in clockwise direction, and terminate
                [Lat, Lon] = poly2ccw(coordMat(:,2),coordMat(:,1));
                if geom==3
                    Lon = [Lon;NaN];
                    Lat = [Lat;NaN];
                end

                % Create structure
                kmlStruct(ii).geometry = geometry;
                kmlStruct(ii).name = name;
                kmlStruct(ii).description = desc;
                kmlStruct(ii).longitude = Lon;
                kmlStruct(ii).latitude = Lat;
                kmlStruct(ii).boundingBox = [min(Lon) min(Lat);max(Lon) max(Lat)];
            end
        end

        function [spline_lat,spline_lon] = google_earth_spline(~,lat,lon)

            lat_xx = linspace(lat(1),lat(end),30);

            lon_xx = spline(lat,lon,lat_xx);

            spline_lat = lat_xx';
            spline_lon = lon_xx';
        end
    end
end

