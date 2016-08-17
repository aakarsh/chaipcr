###
Chai PCR - Software platform for Open qPCR and Chai's Real-Time PCR instruments.
For more information visit http://www.chaibio.com

Copyright 2016 Chai Biotechnologies Inc. <info@chaibio.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
###
window.ChaiBioTech.ngApp.directive 'scrollbar', [
  '$window'
  'TextSelection'
  ($window, textSelection) ->
    restrict: 'E'
    replace: true
    templateUrl: 'app/views/directives/scrollbar.html'
    scope:
      state: '=' # [{0..1}, width]
    require: 'ngModel'
    link: ($scope, elem, attr, ngModel) ->

      held = false
      oldMargin = 0;
      newMargin = 0;
      pageX = 0
      margin = 0
      spaceWidth = 0
      scrollbar_width = 0
      xDiff = 0

      scrollbar = elem.find('.scrollbar')

      $scope.$watchCollection ->
        ngModel.$viewValue
      , (val, oldVal) ->
        if (val?.value isnt oldVal?.value or val?.width isnt oldVal?.width) and !held
          value = val.value*1 || ngModel.$viewValue.value || 0
          value = if (value > 1) then 1 else value
          value = if (value < 0) then 0 else value

          # if angular.isNumber(value)
            # newMargin = getSpaceWidth() * value
            # updateMargin(newMargin)
          # console.log val

          elem_width = getElemWidth()
          width_percent = val.width || ngModel.$viewValue.width || 1
          new_width = elem_width * width_percent
          new_width = if new_width >= 15 then new_width else 15
          scrollbar.css('width', "#{new_width}px")
          new_margin = (elem_width - new_width) * value
          # console.log "new margin: #{new_margin}"
          updateMargin(new_margin)

      # width_percent = {0..1}
      # $scope.$watch 'width', (width_percent) ->
      #   width_percent = width_percent || 1
      #   new_width = getElemWidth() * width_percent
      #   new_width = if new_width >= 15 then new_width else 15
      #   scrollbar.css('width', "#{new_width}px")
      #   new_margin = (getElemWidth() - new_width) * ngModel.$viewValue
      #   updateMargin(new_margin)

      getMarginLeft = ->
        parseInt scrollbar.css('marginLeft').replace /px/, ''

      getElemWidth = ->
        parseInt elem.css('width').replace /px/, ''

      getScrollBarWidth = ->
        parseInt scrollbar.css('width').replace /px/, ''

      getSpaceWidth = ->
        getElemWidth() - getScrollBarWidth()

      updateMargin = (newMargin) ->
        spaceWidth = getSpaceWidth()
        if newMargin > spaceWidth then newMargin = spaceWidth
        if newMargin < 0 then newMargin = 0
        scrollbar.css marginLeft: "#{newMargin}px"

      elem.on 'mousedown', (e) ->
        held = true
        pageX = e.pageX
        textSelection.disable()

        oldMargin = getMarginLeft()
        spaceWidth = getSpaceWidth()
        scrollbar_width = getScrollBarWidth()


      $window.$(document).on 'mouseup', (e) ->
        held = false
        textSelection.enable()

      $window.$(document).on 'mousemove', (e) ->
        if held
          xDiff = e.pageX - pageX
          newMargin = oldMargin + xDiff

          updateMargin(newMargin)

          # avoid dividing with spaceWidth = 0, else result is NaN
          val = if spaceWidth > 0 then Math.round((newMargin)/spaceWidth*1000)/1000 else 0
          ngModel.$setViewValue({
            value: val,
            scrollbar_width
          })

]