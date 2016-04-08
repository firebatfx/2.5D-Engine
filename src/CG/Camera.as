package CG
{
	
	import flash.geom.Matrix3D;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.geom.Vector3D;
	
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Quad;
	import starling.display.Sprite;
	
	public class Camera extends Sprite
	{
		public static const TILE_HEIGHT:Number = 40;
		public static const TILE_WIDTH:Number = 40;
		
		private var centerTarget:DisplayObject;
		private var centerOffsetY:int = -20;
		private var centerOffsetX:int = 0;
		private var cgSprite:CgSprite;
		private var tempPoint:Point = new Point();
		
		public static var worldToIsometricMatrix:Matrix3D = new Matrix3D();
		
		{
			//static constructor
			//90 - 35.26439  <---------- true isometric
			//90- 26.565 <----------- dimetric where width = 2*height
			worldToIsometricMatrix.appendRotation(45, Vector3D.Z_AXIS);
			worldToIsometricMatrix.appendRotation(60, Vector3D.X_AXIS);
			worldToIsometricMatrix.appendScale(1.414, 1.414, 1.414); //sqrt2
		}
		
		public static var isometricToWorldMatrix:Matrix3D;
		{
			isometricToWorldMatrix = worldToIsometricMatrix.clone();
			isometricToWorldMatrix.invert();
		}
		
		private static var worldFarPlaneCatche:Number = 0;
		private static var point3D:Vector3D = new Vector3D();
		
		public function Camera(_cgSprite:CgSprite)
		{
			super();
			cgSprite = _cgSprite;
		}
		
		/**Returns depth based on a world height and tile height
		 * depth = 1 means that object will cover just one tile in depth*/
		public static function calculateDepth(_depth:Number):Number
		{
			return TILE_HEIGHT * _depth / worldFarPlane;
		}
		
		public static function get worldFarPlane():Number
		{
			if (worldFarPlaneCatche == 0)
			{
				worldFarPlaneCatche = worldToIsometric(CgSprite.worldWidth , CgSprite.worldHeight).y;
			}
			return worldFarPlaneCatche;
		}
		
		/**Changing world caordinate system (z up) to isometric system.
		 * @param _cartX,_cartY,_cartZ :caordinates of world object
		 * @param _resultPoint: if given, in this point will be stored result instead of creating new one*/
		public static function worldToIsometric(_cartX:int, _cartY:int, _cartZ:int = 0, _resultPoint:Point = null):Point
		{
			var pointIso:Point = (_resultPoint || new Point());
			
			point3D.setTo(_cartX, _cartY, _cartZ);
			point3D = worldToIsometricMatrix.transformVector(point3D);
			pointIso.setTo(point3D.x, point3D.y);
			return pointIso;
		}
		
		/**Changing isometric caords (2d) to world caordinates (3d) with z=0;
		 * @param _cartX,_cartY :caordinates of isometric
		 * @param _resultPoint: if given, in this point will be stored result instead of creating new one*/
		public static function isometricToWorld(_cartX:int, _cartY:int, _resultPoint:Vector3D = null):Vector3D
		{
			var pointCart:Vector3D = (_resultPoint || new Vector3D());
			pointCart.x = (2 * _cartY + _cartX) / 2;
			pointCart.y = (2 * _cartY - _cartX) / 2;
			
			return pointCart;
		}
		
		public function cameraMove(_dx:int, _dy:int):void
		{
			cgSprite.x += _dx;
			cgSprite.y += _dy;
		
		}
		
		public function set centerCameraOffsetX(_value:int):void  { centerOffsetX = _value }
		;
		
		public function get centerCameraOffsetX():int  { return centerOffsetX }
		;
		
		public function set centerCameraOffsetY(_value:int):void  { centerOffsetY = _value }
		;
		
		public function get centerCameraOffsetY():int  { return centerOffsetY }
		;

	}
}