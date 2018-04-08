
xlsFile='./+publicsim/+tests/+pointableSensorTest/pointableSensorTestComplex.xlsx';
xm=publicsim.models.excelBased.excelModelBuilder(xlsFile);
%Do any agent manip here:
%xm.simInst

xm.run();

%Post Processing
log=xm.getLogger();
% positionProcessor = publicsim.analysis.basic.Movement(log);
% positionProcessor.plotOnEarth(xm.simEarth);

sensorProcessor = publicsim.analysis.functional.Sensing(log);
% sensorProcessor.plotObservations();
sensorProcessor.plotObservations
out = sensorProcessor.getObservationsBySensor();

% taskingProcessor = publicsim.analysis.functional.Tasking(log);
% taskingProcessor.plotTaskingByTime();
% taskingProcessor.plotTaskingByTasker();
% taskingProcessor.plotCommandCountByTaskable();

detectionsProcessor = publicsim.analysis.combined.Detections(log);
detectionsProcessor.plotAllAzElRBySensor()