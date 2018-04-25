describe("Testing temp directive", function() {

    var _$rootScope, _$scope, _allowAdminToggle, _$compile, httpMock, compiledScope, _ExperimentLoader, _canvas, _$timeout, _$uibModal,
    _alerts, _popupStatus, _TimeService, _addStageService;

    beforeEach(function() {

        module("ChaiBioTech", function($provide) {
            $provide.value('IsTouchScreen', function () {});
        });

        inject(function($injector) {

            _$rootScope = $injector.get('$rootScope');
            _$scope = _$rootScope.$new();
            _$compile = $injector.get('$compile');
            _ExperimentLoader = $injector.get('ExperimentLoader');
            _canvas = $injector.get('canvas');
            _$timeout = $injector.get('$timeout');
            _HomePageDelete = $injector.get('HomePageDelete');
            _$uibModal = $injector.get('$uibModal');
            _alerts = $injector.get('alerts');
            _popupStatus = $injector.get('popupStatus');
            httpMock = $injector.get('$httpBackend');
            _TimeService = $injector.get('TimeService');
            _addStageService = $injector.get('addStageService');

            httpMock.expectGET("http://localhost:8000/status").respond("NOTHING");
            httpMock.expectGET("http://localhost:8000/network/wlan").respond("NOTHING");
            httpMock.expectGET("http://localhost:8000/network/eth0").respond("NOTHING");
            httpMock.whenGET("/experiments/10").respond("NOTHING");

            var stage = {
                auto_delta: true
            };

            var step = {
                delta_duration_s: 10,
                hold_time: 20,
                pause: true
            };

            var elem = angular.element('<temp caption="Δ Temp" unit="ºC" delta="stage.auto_delta" reading="step.delta_temperature"><capsule func="changeDeltaTemperature" delta="{{stage.auto_delta}}" data="step.delta_temperature"></capsule></temp>');
            var compiled = _$compile(elem)(_$scope);
            _$scope.show = true;
            _$scope.$digest();
            compiledScope = compiled.isolateScope();
            
        });
    });

    it("It should test initial values", function() {
        
        expect(compiledScope.edit).toEqual(false);
        expect(compiledScope.showCapsule).toEqual(true);
    });

    it("It should test change in reading", function() {

        compiledScope.reading = 10.10;
        compiledScope.$digest();
        expect(compiledScope.shown).toEqual('10.1');
    });

    it("It should test editAndFocus method", function() {

        compiledScope.delta = true;
        compiledScope.reading = 10.111;
        
        compiledScope.$digest();

        compiledScope.editAndFocus();

        expect(compiledScope.shown).toEqual('10.1');
        expect(compiledScope.edit).toEqual(true);
        
    });

    it("It should test save method when show is a number", function() {

        compiledScope.shown = 10;
        compiledScope.$digest();

        compiledScope.editAndFocus();

        compiledScope.shown = 15;
        compiledScope.$digest();

        compiledScope.save();
        
        expect(compiledScope.edit).toEqual(false);
        expect(compiledScope.reading).toEqual(compiledScope.shown);
    });

    it("It should test save method when show is not a number", function() {

        spyOn(_alerts, "showMessage").and.returnValue();

        compiledScope.shown = 'wow';
        compiledScope.$digest();

        compiledScope.editAndFocus();

        compiledScope.shown = 'wow';
        compiledScope.$digest();

        compiledScope.save();
        
        expect(_alerts.showMessage).toHaveBeenCalled();

    });

});