package {

    import flash.display.Sprite;

    [SWF(width="641", height="481", backgroundColor="#FFFFFF")]
    public class haberdasher extends Sprite {

	private var _scene:Scene;

	public function haberdasher():void {
	    _scene = new Scene();
	    addChild(_scene);
            _scene.init();
            _scene.initLevel(3,
                [[[0, 0], [2, 0], [2, 2], [4, 2], [4, 4], [0, 4]]],
                [{ type: "drag", id: 0, dx: 6, dy: 4 },
                 { type: "slice", x0: 6, y0: 8, x1: 8, y1: 4 },
                 { type: "slice", x0: 6, y0: 8, x1: 10, y1: 6 },
                 { type: "rotate", id: 0, r: 2 },
                 { type: "drag", id: 0, dx: 16, dy: 12 },
                 { type: "slice", x0: 6, y0: 6, x1: 8, y1: 4 },
                 // Right tail
                 { type: "rotate", id: 0, r: 3 },
                 { type: "drag", id: 0, dx: 4, dy: 12 },
                 // Left tail
                 { type: "rotate", id: 3, r: 3 },
                 { type: "drag", id: 3, dx: 4, dy: 12 },
                 // Middle
                 { type: "rotate", id: 1, r: 3 },
                 { type: "drag", id: 1, dx: 4, dy: 12 },
                 // Nose
                 { type: "rotate", id: 4, r: 3 },
                 { type: "drag", id: 4, dx: 2, dy: 14 }
                ]
            );
	}

    }

}

import flash.display.Bitmap;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.filters.BitmapFilterQuality;
import flash.filters.GlowFilter;
import flash.geom.Point;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFormat;
import com.flassari.geom.Clipper;
import com.flassari.geom.ClipType;

const TIME_STEP:Number = 20;
const GRID_SIZE:int = 40;
const GRID_DIV:int = 4;

internal class Scene extends Sprite {

    private var _patchLayer:PatchLayer = new PatchLayer();
    private var _sliceLine:SliceLine = new SliceLine();
    private var _solution:Solution = new Solution(0x00FF00);
    private var _solutionGhost:Solution = new Solution(0xFF00FF);
    private var _sliceCount:int = 0;
    private var _sliceCountLabel:TextField = new TextField();

    public function Scene():void {
    }

    public function init():void {
        // Interactive layers
        addChild(_patchLayer);
        addChild(_sliceLine);
        addChild(_solution);
        addChild(_solutionGhost);

        // Backdrop (also needed to catch mouse events)
        graphics.beginFill(0xFFFFFF);
	graphics.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
        graphics.endFill();

        // Grid
        var x:int, y:int;

        graphics.beginFill(0x9999BB);
        for (x = 0; x <= stage.stageWidth; x += GRID_SIZE) {
            for (y = 0; y <= stage.stageHeight; y += GRID_DIV) {
                graphics.drawCircle(x, y, GRID_DIV * 0.25);
            }
        }
        graphics.endFill();

        graphics.beginFill(0x9999BB);
        for (y = 0; y <= stage.stageHeight; y += GRID_SIZE) {
            for (x = 0; x <= stage.stageWidth; x += GRID_DIV) {
                graphics.drawCircle(x, y, GRID_DIV * 0.25);
            }
        }
        graphics.endFill();

	addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
	addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
	addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);

        _sliceCountLabel.autoSize = TextFieldAutoSize.LEFT;
        _sliceCountLabel.defaultTextFormat = new TextFormat("Arial", 24, 0x000000);
        _sliceCountLabel.text = ""
        _sliceCountLabel.x = 8;
        _sliceCountLabel.y = 8;
        addChild(_sliceCountLabel);
    }

    public function initLevel(sliceCount:int, shapes:Array, steps:Array):void {
        var polys:Array = [];
        var poly:Array;
        var i:int;

        _sliceCount = sliceCount;
        _sliceCountLabel.text = "Remaining slices: " + sliceCount;

        for each (var shape:Array in shapes) {
            poly = makePoints(shape, GRID_SIZE);
            _patchLayer.newPatch(poly);
            polys.push(poly);
        }

        for each (var step:Object in steps) {
            switch (step.type) {
            case "drag":
                polys[step.id].forEach(function(pt:Point, i:int, a:Array):void { pt.offset(step.dx * GRID_SIZE, step.dy * GRID_SIZE); });
                break;
            case "rotate":
                polys[step.id].forEach(function(pt:Point, i:int, a:Array):void {
                    var x:int, y:int;
                    switch (step.r) {
                    case 1: x = -pt.y; y = pt.x; break;
                    case 2: x = -pt.x; y = -pt.y; break;
                    case 3: x = pt.y; y = -pt.x; break;
                    }
                    pt.x = x;
                    pt.y = y;
                });
                break;
            case "slice":
                var slice:Array = _sliceLine.getPolygonFromSegment(step.x0, step.y0, step.x1, step.y1);
                var addToPolys:Function = function(p:Array, i:int, a:Array):void { polys.push(p); }
                var n:int = polys.length;
                for (i = 0; i < n; i++) {
                    poly = polys.shift();
                    Clipper.clipPolygon(poly, slice, ClipType.DIFFERENCE).forEach(addToPolys);
                    Clipper.clipPolygon(poly, slice, ClipType.INTERSECTION).forEach(addToPolys);
                }
                break;
            }
        }

        _solution.setPoints(unionAll(polys));
    }

    // Note: this destroys the input!
    private function unionAll(polys:Array):Array {
        // Ugly hack to work around the limitations of the Clipper wrapper
        // (that it only accepts single polygons as input)
        var union:Array = [polys.shift()];
        for each (var poly:Array in polys) {
            var found:Boolean = false;

            for (var i:int = 0; i < union.length; i++) {
                var pieces:Array = Clipper.clipPolygon(poly, union[i], ClipType.UNION);
                if (pieces.length == 1) {
                    union.splice(i, 1);
                    polys.push(pieces[0]);
                    found = true;
                    break;
                }
            }

            if (!found) {
                union.push(poly);
            }
        }

        return union;
    }

    private function onMouseDown(e:MouseEvent):void {
        if (_sliceCount > 0) {
            _sliceLine.beginSlicing();
        }
    }

    private function onMouseUp(e:MouseEvent):void {
        _patchLayer.stopDragging();
        if (_sliceLine.endSlicing()) {
            var slice:Array = _sliceLine.getPolygon();
            if (slice.length > 0) {
                _patchLayer.slicePatches(slice);
                _sliceCount--;
                _sliceCountLabel.text = _sliceCount == 0 ? "No slices left" : "Slices left: " + _sliceCount;
            }
        }

        if (checkSolution()) {
            _sliceCountLabel.text = "Success!";
        }
    }

    private function onMouseMove(e:MouseEvent):void {
        _sliceLine.updatePosition();
        _patchLayer.updatePosition(e.stageX, e.stageY);
    }

    private function makePoints(coords:Array, scale:int = 1):Array {
        return coords.map(function(xy:Array, i:int, a:Array):Point { return new Point(xy[0] * scale, xy[1] * scale); });
    }

    private function checkSolution():Boolean {
        var polys:Array = [];
        var n:int = _patchLayer.numChildren;
        var i:int;

        for (i = 0; i < n; i++) {
            polys.push((_patchLayer.getChildAt(i) as Patch).getPolygon());
        }

        // We only handle puzzles with connected solutions (the
        // limitations of the Clipper wrapper are the cause of the
        // laziness again)
        var union:Array = unionAll(polys);
        var target:Array = _solution.points;

        // This is only for testing
        //_solutionGhost.setPoints(union);

        if (target.length != 1 || union.length != 1) {
            return false;
        }

        var poly1:Array = union[0];
        var poly2:Array = target[0];
        var poly:Array;

        var a1:Number = 0, a2:Number = 0;
        for each (poly in Clipper.clipPolygon(poly1, poly2, ClipType.DIFFERENCE)) {
            a1 += polygonArea(poly);
        }

        for each (poly in Clipper.clipPolygon(poly2, poly1, ClipType.DIFFERENCE)) {
            a2 += polygonArea(poly);
        }

        // A wild guess that works with the only existing puzzle...
        return a1 + a2 <= GRID_SIZE * GRID_SIZE / 4; 
    }

    private function polygonArea(p:Array):Number {
        var a:Number = 0;
        var n:int = p.length;

        for (var i:int = 0; i < n; i++) {
            a += p[i].x * p[(i + 1) % n].y - p[i].y * p[(i + 1) % n].x;
        }

        return Math.abs(a);
    }

}

internal class SliceLine extends Sprite {

    private const DASH_LENGTH:Number = 8;

    private var _slicing:Boolean = false;

    private var _px0:int = -1;
    private var _py0:int = -1;
    private var _px1:int = -1;
    private var _py1:int = -1;

    public function SliceLine():void {
    }

    private function getLine(xa:int, ya:int, xb:int, yb:int):Object {
        var t:Boolean, m:Number;
        var x0:Number, y0:Number, x1:Number, y1:Number;

        t = Math.abs(xb - xa) > Math.abs(yb - ya);
        if (t) {
            m = (yb - ya) / (xb - xa);
            x0 = 0;
            x1 = stage.stageWidth - 1;
            y0 = ya - xa * m;
            y1 = ya + (stage.stageWidth - xa) * m;
        } else {
            m = (xb - xa) / (yb - ya);
            y0 = 0;
            y1 = stage.stageHeight - 1;
            x0 = xa - ya * m;
            x1 = xa + (stage.stageHeight - ya) * m;
        }
        
        return { x0: x0, y0: y0, x1: x1, y1: y1, type: t };
    }

    public function getPolygon():Array {
        return getPolygonFromSegment(_px0, _py0, _px1, _py1);
    }

    public function getPolygonFromSegment(px0:int, py0:int, px1:int, py1:int):Array {
        var line:Object = getLine(px0 * GRID_SIZE, py0 * GRID_SIZE, px1 * GRID_SIZE, py1 * GRID_SIZE);
        if ((px0 == px1 && py0 == py1) || (line.x0 == line.x1 && line.y0 == line.y1)) {
            return [];
        } else {
            return [new Point(0, 0), new Point(line.x0, line.y0), new Point(line.x1, line.y1),
                    line.type ? new Point(stage.stageWidth - 1, 0) : new Point(0, stage.stageHeight - 1)];
        }
    }

    public function beginSlicing():void {
        if (!_slicing) {
            _slicing = true;
            _px1 = -1;
            _py1 = -1;
            updatePosition();
        }
    }

    public function endSlicing():Boolean {
        var slicing:Boolean = _slicing;
        _slicing = false;
        return slicing;
    }

    public function updatePosition():void {
        var px:int = (mouseX + GRID_SIZE / 2) / GRID_SIZE;
        var py:int = (mouseY + GRID_SIZE / 2) / GRID_SIZE;

        if (_slicing) {
            if (px != _px1 || py != _py1) {
                graphics.clear();
                graphics.lineStyle(2, 0x000000);
                graphics.drawCircle(_px0 * GRID_SIZE, _py0 * GRID_SIZE, GRID_DIV);
                graphics.drawCircle(px * GRID_SIZE, py * GRID_SIZE, GRID_DIV);
                var line:Object = getLine(_px0 * GRID_SIZE, _py0 * GRID_SIZE, px * GRID_SIZE, py * GRID_SIZE);
                var dx:Number = line.x1 - line.x0;
                var dy:Number = line.y1 - line.y0;
                if (dx != 0 || dy != 0) {
                    var d:Number = Math.sqrt(dx * dx + dy * dy);
                    var lx:Number = line.x0;
                    var ly:Number = line.y0;
                    dx *= DASH_LENGTH / d;
                    dy *= DASH_LENGTH / d;
                    graphics.lineStyle(3, 0xFF0000, 0.5);
                    for (var t:Number = 0; t < d; t += DASH_LENGTH * 2) {
                        graphics.moveTo(lx, ly);
                        graphics.lineTo(lx + dx, ly + dy);
                        lx += dx * 2;
                        ly += dy * 2;
                    }
                }
                _px1 = px;
                _py1 = py;
            }
        } else {
            if (px != _px0 || py != _py0) {
                graphics.clear();
                graphics.lineStyle(2, 0x000000, 0.5);
                graphics.drawCircle(px * GRID_SIZE, py * GRID_SIZE, GRID_DIV);
                _px0 = px;
                _py0 = py;
            }
        }
    }

}

internal class PatchLayer extends Sprite {

    public function PatchLayer():void {
    }

    public function newPatch(points:Array):void {        
        addChild(new Patch(stage, points));
    }

    public function stopDragging():void {
        for (var i:int = 0; i < numChildren; i++) {
            (getChildAt(i) as Patch).stopDragging();
        }
    }

    public function updatePosition(mx:Number, my:Number):void {
        for (var i:int = 0; i < numChildren; i++) {
            (getChildAt(i) as Patch).updatePosition(mx, my);
        }
    }


    public function slicePatches(slice:Array):void {
        var removed:Vector.<Patch> = new Vector.<Patch>();
        var n:int = numChildren;
        var p:Patch;

        for (var i:int = 0; i < n; i++) {
            p = getChildAt(i) as Patch;
            var poly:Array = p.getPolygon();

            var clip1:Array = Clipper.clipPolygon(poly, slice, ClipType.DIFFERENCE);
            var clip2:Array = Clipper.clipPolygon(poly, slice, ClipType.INTERSECTION);

            if (clip1.length > 0 && clip2.length > 0) {
                removed.push(p);
                var f:Function = function(pts:Array, i:int, a:Array):void { newPatch(pts); };
                clip1.forEach(f);
                clip2.forEach(f);
            }
        }

        for each (p in removed) {
            removeChild(p);
        }
    }

}

internal class Patch extends Sprite {

    private var _origin:Point;
    private var _offset:Point;
    private var _orientation:int = 0;
    private var _dragged:Boolean = false;
    private var _x0:int;
    private var _y0:int;

    private var _points:Array = [];
    private var _width:int;
    private var _height:int;

    [Embed(source="fabric.jpg")]
    private var Texture:Class;

    public function Patch(stage:Stage, points:Array):void {
	var texture:Bitmap = new Texture();
        var xmin:int = 1000000, ymin:int = 1000000;
        var xmax:int = -1000000, ymax:int = -1000000;
        var pt:Point;

        for each (pt in points) {
            xmin = Math.min(xmin, pt.x);
            ymin = Math.min(ymin, pt.y);
            xmax = Math.max(xmax, pt.x);
            ymax = Math.max(ymax, pt.y);
        }

        _origin = new Point(Math.floor(xmin / GRID_SIZE) * GRID_SIZE,
                            Math.floor(ymin / GRID_SIZE) * GRID_SIZE);
        _offset = new Point(0, 0);

        graphics.beginBitmapFill(texture.bitmapData);
        var pt0:Point = points[0].subtract(_origin);
        graphics.moveTo(pt0.x, pt0.y);
        for each (pt in points) {
            var pt2:Point = pt.subtract(_origin);
            graphics.lineTo(pt2.x, pt2.y);
            _points.push(pt2);
        }
        graphics.endFill();

        _width = (xmax - _origin.x - 1) / GRID_SIZE + 1;
        _height = (ymax - _origin.y - 1) / GRID_SIZE + 1;
        _width *= GRID_SIZE;
        _height *= GRID_SIZE;

        filters = [new GlowFilter(0x43311D, 1, 20, 20, 1, BitmapFilterQuality.HIGH, true, false)];

        x = _origin.x;
        y = _origin.y;

	addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
    }

    private function onMouseDown(e:MouseEvent):void {
        if (e.shiftKey) {
            var tmp:int = _width;
            _width = _height;
            _height = tmp;

            _orientation = (_orientation + 1) % 4;
            switch (_orientation) {
            case 0:
                _offset.x = 0;
                _offset.y = 0;
                break;
            case 1:
                _offset.x = _width;
                _offset.y = 0;
                break;
            case 2:
                _offset.x = _width;
                _offset.y = _height;
                break;
            case 3:
                _offset.x = 0;
                _offset.y = _height;
                break;
            }

            x = _origin.x + _offset.x;
            y = _origin.y + _offset.y;
            rotation = _orientation * 90;
        } else {
            _dragged = true;
            _x0 = e.stageX;
            _y0 = e.stageY;
            parent.setChildIndex(this, parent.numChildren - 1);
        }
        e.stopPropagation();
    }

    public function stopDragging():void {
        if (_dragged) {
            _dragged = false;
            _origin.x = x - _offset.x;
            _origin.y = y - _offset.y;
        }
    }

    public function updatePosition(mx:Number, my:Number):void {
        if (_dragged) {
            var dx:int = (mx - _x0) / GRID_SIZE;
            var dy:int = (my - _y0) / GRID_SIZE;
            x = Math.min(stage.stageWidth - _width - 1, Math.max(0, _origin.x + dx * GRID_SIZE)) + _offset.x;
            y = Math.min(stage.stageHeight - _height - 1, Math.max(0, _origin.y + dy * GRID_SIZE)) + _offset.y;
        }
    }

    private function transformPoint(pt:Point):Point {
        var pt2:Point;

        switch (_orientation) {
        case 0:
            pt2 = pt.clone();
            break;
        case 1:
            pt2 = new Point(-pt.y, pt.x);
            break;
        case 2:
            pt2 = new Point(-pt.x, -pt.y);
            break;
        case 3:
            pt2 = new Point(pt.y, -pt.x);
            break;
        }

        return pt2.add(_origin).add(_offset);
    }

    public function getPolygon():Array {
        return _points.map(function(pt:Point, i:int, a:Array):Point { return transformPoint(pt); });
    }

}

internal class Solution extends Sprite {

    private var _polys:Array;
    private var _colour:int;

    public function Solution(colour:int):void {
        _colour = colour;
    }

    public function get points():Array {
        return _polys;
    }

    public function setPoints(polys:Array):void {
        graphics.clear();
        graphics.lineStyle(3, _colour, 0.5);
        for each (var poly:Array in polys) {
            var n:int = poly.length - 1;
            graphics.moveTo(poly[n].x, poly[n].y);
            for each (var pt:Point in poly) {
                graphics.lineTo(pt.x, pt.y);
            }
        }

        _polys = polys;
    }

}
