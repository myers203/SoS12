
logPath = './tmp';
tsim=publicsim.sim.Instance(logPath);

mt{1}=publicsim.tests.agents.base.MovableTest(0,[100 100 100],[10 10 10],[0 0 0]);
mt{2}=publicsim.tests.agents.base.MovableTest(0,[50 50 50],[5 5 5],[1 1 1]);
for i=1:numel(mt)
    tsim.AddCallee(mt{i});
end
tsim.runUntil(0,100);

logger = publicsim.sim.Logger(logPath);
logger.restore();

logger2 = publicsim.sim.Logger(logPath2);
logger2.restore;

coordinator = publicsim.analysis.Coordinator();

movementAnalyzer = coordinator.requestAnalyzer('publicsim.analysis.basic.Movement', logger);

world = publicsim.util.Earth();
world.setModel('elliptical');

movementAnalyzer.plotOnEarth(world);

movementAnalyzer2 = coordinator.requestAnalyzer('publicsim.analysis.basic.Movement', logger);

tic;
data = movementAnalyzer.getPositionsForClass('tests.agents.base.MovableTest');
time1 = toc;

data = movementAnalyzer.getPositionsForClass('tests.agents.base.MovableTest2');

numTries = 1000;
time2 = 0;
for i = 1:numTries
    tic;
    data = movementAnalyzer2.getPositionsForClass('tests.agents.base.MovableTest');
    time2 = time2 + toc;
end
time2 = time2 / numTries;
disp(time1);
disp(time2);
disp(time2 / time1);