classdef mrViewer < handle
  properties
    idx (1,1) double = 1            % current slice index
    orientation (1,:) char = 'Z'    % viewing plane ('X','Y','Z')
    imgVol                           % 3D image volume
    maskVol = []                     % Optional mask volume
    maxIdx (1,1) double             % maximum slices in current orientation
  end

  methods
    function obj = mrViewer(imageMr, maskMr)
      % Constructor: initialize data and build UI
      if nargin < 1
        error('Must provide an input volume.');
      end
      obj.imgVol = double(imageMr.dataAy);
      if nargin >= 2 && ~isempty(maskMr)
        obj.maskVol = double(maskMr.dataAy);
      end

      % Create UI figure and grid with 3 columns so we can insert a slider
      fig = uifigure('Name','mrViewer','Position', [100 100 600 800]);
      gl = uigridlayout(fig, [4 3]);
      gl.RowHeight   = {30, '1x', 30, 30};
      gl.ColumnWidth = {50, '1x', 50};

      % Orientation label
      lblOri = uilabel(gl, 'Text', 'Orientation:');
      lblOri.Layout.Row    = 1;
      lblOri.Layout.Column = 1;

      % Orientation dropdown
      ddOri = uidropdown(gl, ...
        'Items', {'X', 'Y', 'Z'}, ...
        'Value', obj.orientation);
      ddOri.Layout.Row    = 1;
      ddOri.Layout.Column = 2;

      % Axes for image display
      ax = uiaxes(gl);
      ax.Interactions    = [];
      ax.Toolbar.Visible = 'off';
      ax.Layout.Row      = 2;
      ax.Layout.Column   = [1 3];

      % Navigation buttons
      btnL = uibutton(gl, 'Text', '←');
      btnL.Layout.Row    = 3;
      btnL.Layout.Column = 1;
      btnR = uibutton(gl, 'Text', '→');
      btnR.Layout.Row    = 3;
      btnR.Layout.Column = 3;

      % Slider between buttons
      sld = uislider(gl);
      sld.Layout.Row    = 3;
      sld.Layout.Column = 2;

      % Label showing current slice / max
      lblSlice = uilabel(gl);
      lblSlice.Layout.Row    = 4;
      lblSlice.Layout.Column = [1 3];

      % Assign callbacks (after all handles exist)
      ddOri.ValueChangedFcn     = @(s,e) obj.onOrientationChanged(e, ax, lblSlice, sld);
      btnL.ButtonPushedFcn       = @(s,e) obj.leftClick(ax, lblSlice, sld);
      btnR.ButtonPushedFcn       = @(s,e) obj.rightClick(ax, lblSlice, sld);
      sld.ValueChangedFcn        = @(s,e) obj.onSliderChanged(e, ax, lblSlice, sld);
      sld.ValueChangingFcn       = @(s,e) obj.onSliderChanging(e, ax, lblSlice, sld);

      % Initialize and display first slice
      obj.updateMax(sld);
      obj.idx = 1;
      obj.showSlice(ax, lblSlice, sld);
    end

    function updateMax(obj, sld)
      % Determine max slices for the selected orientation and update slider
      dims = size(obj.imgVol);
      switch obj.orientation
        case 'X'
          obj.maxIdx = dims(1);
        case 'Y'
          obj.maxIdx = dims(2);
        otherwise
          obj.maxIdx = dims(3);
      end
      sld.Limits         = [1 obj.maxIdx];
      sld.MajorTicks     = 1:ceil(obj.maxIdx/20):obj.maxIdx;
      sld.MajorTickLabels= {};
      sld.Value          = obj.idx;
    end

    function onOrientationChanged(obj, event, ax, lblSlice, sld)
      % Handle orientation dropdown change
      obj.orientation = event.Value;
      obj.idx = 1;
      obj.updateMax(sld);
      obj.showSlice(ax, lblSlice, sld);
    end

    function onSliderChanged(obj, event, ax, lblSlice, sld)
      % Handle slider release change
      obj.idx = round(event.Value);
      obj.showSlice(ax, lblSlice, sld);
    end

    function onSliderChanging(obj, event, ax, lblSlice, sld)
      % Handle slider drag (continuous update)
      idxDrag = round(event.Value);
      if idxDrag~=obj.idx
        obj.idx = idxDrag;
        obj.showSlice(ax, lblSlice, sld);
      end
    end

    function leftClick(obj, ax, lblSlice, sld)
      % Decrement slice index
      obj.idx = max(1, obj.idx - 1);
      sld.Value = obj.idx;
      obj.showSlice(ax, lblSlice, sld);
    end

    function rightClick(obj, ax, lblSlice, sld)
      % Increment slice index
      obj.idx = min(obj.maxIdx, obj.idx + 1);
      sld.Value = obj.idx;
      obj.showSlice(ax, lblSlice, sld);
    end

    function showSlice(obj, ax, lblSlice, sld)
      % Display the current slice in the chosen orientation
      switch obj.orientation
        case 'X'
          slice = squeeze(obj.imgVol(obj.idx, :, :));
          if ~isempty(obj.maskVol), msk = squeeze(obj.maskVol(obj.idx, :, :)); end
        case 'Y'
          slice = squeeze(obj.imgVol(:, obj.idx, :));
          if ~isempty(obj.maskVol), msk = squeeze(obj.maskVol(:, obj.idx, :)); end
        otherwise
          slice = obj.imgVol(:, :, obj.idx);
          if ~isempty(obj.maskVol), msk = obj.maskVol(:, :, obj.idx); end
      end
      imshow(slice, [], 'Parent', ax);
      hold(ax,'on');
      if ~isempty(obj.maskVol)
        maskRGB = cat(3, ones(size(msk)), zeros(size(msk)), zeros(size(msk)));
        h = imshow(maskRGB, 'Parent', ax);
        h.AlphaData = (msk>0)*0.3;
      end
      hold(ax,'off');
      lblSlice.Text = sprintf('Slice %d / %d', obj.idx, obj.maxIdx);
    end
  end
end
