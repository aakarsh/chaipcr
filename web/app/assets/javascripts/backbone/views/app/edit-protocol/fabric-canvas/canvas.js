ChaiBioTech.app.Views = ChaiBioTech.app.Views || {};

ChaiBioTech.app.Views.mainCanvas = null; // This could be used across application to fire

ChaiBioTech.app.Views.fabricCanvas = function(model, appRouter) {

  this.model = model;
  this.allStepViews = [];
  var that = this;

  ChaiBioTech.app.Views.mainCanvas = this.canvas = new fabric.Canvas('canvas', {
    backgroundColor: '#ffb400',
    selection: false,
    stateful: true
  });

  this.fireUpEvents = new ChaiBioTech.app.Views.fabricEvents(this);

  this.setDefaultWidthHeight = function() {
    this.canvas.setHeight(420);
    var width = (this.allStepViews.length * 122 > 1024) ? this.allStepViews.length * 120 : 1024
    this.canvas.setWidth(width + 50);
    this.canvas.renderAll();
    return this;
  };


  this.selectStep = function() {
    this.allStepViews[0].circle.manageClick(true);
    this.canvas.renderAll();
    appRouter.editStageStep.trigger("stepSelected", this.allStepViews[0]);
  }

  this.addStages = function() {
    var allStages = this.model.get("experiment").protocol.stages;
    var stage = {};
    var previousStage = null;

    for (stageIndex in allStages) {
      stageModel = new ChaiBioTech.Models.Stage({"stage": allStages[stageIndex].stage});
      stageView = new ChaiBioTech.app.Views.fabricStage(stageModel, this.canvas, this.allStepViews, stageIndex, this);

      if(previousStage){
        previousStage.nextStage = stageView;
        stageView.previousStage = previousStage;
      }

      previousStage = stageView;
      stageView.render();
    }
    // Only for the last stage
    stageView.borderRight();
    this.canvas.add(stageView.borderRight);
    stageView.findLastStep();
    return this;
  };

  this.addRampLinesAndCircles = function() {
    this.allCircles = null;
    this.allCircles = this.findAllCircles();
    var i = 0, limit = this.allCircles.length;

    for(i = 0; i < limit; i++) {
      this.allCircles[i].getLinesAndCircles();
    }
  }

  this.addinvisibleFooterToStep = function() {
    var count = 0, limit = this.allStepViews.length,
    stepDark = "assets/selected-step-01.png",
    stepWhite = "assets/selected-step-02.png",
    stepCommon = "assets/common-step.png",
    gatherData = "assets/gather-data.png";
    // Rewrite this part with clone, So that loading is faster
    addImage = function(count, that, url, image, callBack) {
      fabric.Image.fromURL(url, function(img) {
        img.left = that.allStepViews[count].left - 1;
        img.top = 383;
        img.selectable = false;
        img.visible = false;

        if(image == "darkFooter") {
          that.allStepViews[count].darkFooterImage = img;
          that.canvas.add(that.allStepViews[count].darkFooterImage);
        } else if(image == "whiteFooter") {
          img.top = 363;
          img.left = that.allStepViews[count].left;
          that.allStepViews[count].whiteFooterImage = img;
          that.canvas.add(that.allStepViews[count].whiteFooterImage);
        } else if(image == "commonFooter") {
          that.allStepViews[count].commonFooterImage = img;
          that.canvas.add(that.allStepViews[count].commonFooterImage);
        }

        count = count + 1;

        if(count < limit) {
          addImage(count, that, url, image, callBack);
        } else if(callBack) { // I want it to be called at the end of all the functioin Calls
          callBack();
        }
      });
    }

    addGatheDataImage = function(that, url, count) {
        fabric.Image.fromURL(url, function(img) {
          img.originX = "center";
          img.originY = "center";
          cloneImgObject = function(that, url, count) {
            that.allStepViews[count].circle.gatherDataImage = $.extend({},img);;
            that.allStepViews[count].circle.gatherDataImageMiddle = $.extend({},img);
            that.allStepViews[count].circle.gatherDataImageMiddle.setVisible(false);
            count = count + 1;
            if(count < limit) {
              cloneImgObject(that, url, count);
            }
          }
          cloneImgObject(that, url, 0);
        });
    }
    addGatheDataImage(this, gatherData, 0);
    addImage(0, this, stepCommon, "commonFooter");
    addImage(0, this, stepDark, "darkFooter");
    addImage(0, this, stepWhite, "whiteFooter", function() {
      // This is sent as callback, we need this to be executed after all
      // images are loaded.
      that.canvas.fire("imagesLoaded");
    });
    // Y we have to do like this ?. We should load few small images and images take more time to load
    // So we load all images using recursive function calls, then fire an event to show .
  }


  this.findAllCircles = function() {
    var i = 0, limit = this.allStepViews.length, circles = [], tempCirc = null;
    for(i = 0; i < limit; i++) {
      if(tempCirc) {
        // U could do the switch with array itself,
        // but definitely it doesn't look good.
        this.allStepViews[i].circle["previous"] = tempCirc;
        tempCirc.next = this.allStepViews[i].circle;
      }
      tempCirc = this.allStepViews[i].circle;
      circles.push(this.allStepViews[i].circle);
    }
    return circles;
  }
  return this;
}
