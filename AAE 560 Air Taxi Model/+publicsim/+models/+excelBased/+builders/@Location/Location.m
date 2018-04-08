classdef Location < publicsim.models.excelBased.builders.Builder
    
    properties
        locationData
    end
    
    properties(Access=private,Constant)
        LOCATION_NAME_COLUMN='Location Name';
        TYPE_COLUMN='Type';
        TYPE_RANDOM='Random';
        TYPE_ABSOLUTE='Absolute';
        LATITUDE_COLUMN='Latitude';
        LONGITUDE_COLUMN='Longitude';
        ALTITUDE_COLUMN='Altitude';
        LATITUDE_VARIANCE_COLUMN='Latitude Variance';
        LONGITUDE_VARIANCE_COLUMN='Longitude Variance';
        ALTITUDE_VARIANCE_COLUMN='Altitude Variance';
        LOCATION_DATA_STRUCT=struct('name',[],...
            'type',[],...
            'latitude',[],...
            'longitude',[],...
            'altitude',[],...
            'variance',struct('latitude',[],'longitude',[],'altitude',[]));
    end
    
    methods
        function obj=Location()
        end
        
        function parse(obj,sheetData)
            obj.sheetData=sheetData;
            obj.buildLocationData();
        end
        
        function buildLocationData(obj)
            names=obj.findColumnDataByLabel(obj.LOCATION_NAME_COLUMN);
            latitudes=obj.findColumnDataByLabel(obj.LATITUDE_COLUMN);
            longitudes=obj.findColumnDataByLabel(obj.LONGITUDE_COLUMN);
            altitudes=obj.findColumnDataByLabel(obj.ALTITUDE_COLUMN);
            types=obj.findColumnDataByLabel(obj.TYPE_COLUMN);
            latitudeVariances=obj.findColumnDataByLabel(obj.LATITUDE_VARIANCE_COLUMN);
            longitudeVariances=obj.findColumnDataByLabel(obj.LONGITUDE_VARIANCE_COLUMN);
            altitudeVariances=obj.findColumnDataByLabel(obj.ALTITUDE_VARIANCE_COLUMN);
            
            for i=1:numel(names)
                dataEntry=obj.LOCATION_DATA_STRUCT;
                dataEntry.name=names{i};
                dataEntry.type=types{i};
                dataEntry.latitude=latitudes{i};
                dataEntry.longitude=longitudes{i};
                dataEntry.altitude=altitudes{i};
                if isequal(types{i},obj.TYPE_RANDOM)
                    dataEntry.variance.latitude=latitudeVariances{i};
                    dataEntry.variance.longitude=longitudeVariances{i};
                    dataEntry.variance.altitude=altitudeVariances{i};
                else
                    dataEntry.variance=[];
                end
                obj.locationData{i}=dataEntry;
            end
        end
        
        function lla=getLocationLla(obj,namedLocation)
            location=obj.findEntryByName(obj.locationData,namedLocation);
            lla=[location.latitude location.longitude location.altitude];
            if isequal(location.type,obj.TYPE_RANDOM)
                lla(1)=lla(1)+(rand()-0.5)*location.variance.latitude;
                lla(2)=lla(2)+(rand()-0.5)*location.variance.longitude;
                lla(3)=lla(3)+(rand()-0.5)*location.variance.altitude;
            end
        end
    end
    
end

