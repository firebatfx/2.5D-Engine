package CG
{
	import deferred.DeferredImage;
	import deferred.DeferredLight;
	import deferred.DeferredMovieClip;
	import deferred.DeferredSelectionFilter;
	import deferred.DeferredTexture;
	import flash.geom.Point;
	
	import starling.animation.Tween;
	import starling.display.DisplayObject;
	import starling.display.Image;
	import starling.display.MovieClip;
	import starling.display.Sprite;
	import starling.events.EnterFrameEvent;
	import starling.textures.Texture;
	
	public class CgBody extends Sprite
	{
		public static const SORT_BELOW:int = -1;
		public static const SORT_NORMAL:int = 0;
		public static const SORT_ABOVE:int = 1;

		private var mSubCgBodies:Vector.<SubCgBody> = new Vector.<SubCgBody>();
		private var mColor:uint=0xffffff;
		
		/**indicates if cg body will be push above, belowe, or normal priority on sorting*/
		private var mSorting:int = SORT_NORMAL;
		protected var mZ:int = 0;
		private var texturesVecor:Vector.<String> = new Vector.<String>();
		
		protected var mOffsetX:int=0;
		protected var mOffsetY:int=0;
		protected var mOffsetZ:int=0;
		
		public function CgBody()
		{
			super();
			
		}
		public function setSelection(_selection:DeferredSelectionFilter):void{
			for(var j:int = 0; j < this.numChildren; j++){
				if(this.getChildAt(j) is DeferredImage){
					(this.getChildAt(j) as DeferredImage).selection = _selection;
				}
			}
		}
		public function addSubCgBody(_cgBody:SubCgBody):void{
			mSubCgBodies.push(_cgBody);
			_cgBody.x = this.x+_cgBody.offsetX;
			_cgBody.y = this.y+_cgBody.offsetY;
		}
		/** @inheritDoc */
		public override function dispose():void
		{
			if(mSubCgBodies != null){
				for(var j:int = 0; j < mSubCgBodies.length; j++){ //dispose all subCgBodies
					mSubCgBodies[j].dispose();
				}
			}
			mSubCgBodies = null;
			super.dispose();
		}
		
		/**move subCgBodies on proper position X*/
		override public function set x(value:Number):void 
		{ 
			super.x = value+this.mOffsetX;
			if(mSubCgBodies != null){
				for(var j:int = 0; j < mSubCgBodies.length; j++){ //dispose all subCgBodies
					mSubCgBodies[j].x = value;
				}
			}
		}
		/**move subCgBodies on proper position Y*/
		override public function set y(value:Number):void 
		{ 
			super.y = value+this.mOffsetY;
			if(mSubCgBodies != null){
				for(var j:int = 0; j < mSubCgBodies.length; j++){ //dispose all subCgBodies
					mSubCgBodies[j].y = value;
				}
			}
		}
		public function get z():Number{return mZ};
		/**move subCgBodies on proper position Z*/
		public function set z(value:Number):void 
		{ 
			mZ = value+this.mOffsetZ;
			if(mSubCgBodies != null){
				for(var j:int = 0; j < mSubCgBodies.length; j++){ //dispose all subCgBodies
					mSubCgBodies[j].z = value;
				}
			}
		}
		/**move subCgBodies on proper position Z*/
		override public function set alpha(value:Number):void 
		{ 
			if(mSubCgBodies != null){
				for(var j:int = 0; j < mSubCgBodies.length; j++){ //dispose all subCgBodies
					mSubCgBodies[j].alpha = value;
				}
			}
			for(var k:int = 0; k < this.numChildren; k++){ //dispose all subCgBodies
				this.getChildAt(k).alpha = value;// deferred bodies can be visible or not
			}
		}
		public function set color(_value:uint):void{
			mColor = _value;
		}
		public function get color():uint{
			return mColor;
		}
		/**Give back all subCgBodies attached to this cgBody
		 * */
		public function get subCgBodies():Vector.<SubCgBody>{
			return mSubCgBodies;
		}
		/**Give back sorting. BELOW = -1. NORMAL = 0, ABOVE = 1*/
		public function get sorting():int{
			return mSorting;
		}
		public function set sorting(_value:int):void{
			mSorting = _value;
		}
		public function get offsetZ():int{return mOffsetZ}
		public function set offsetZ(_value:int):void{mOffsetZ = _value}
		
		public function get offsetX():int{return mOffsetX}
		public function set offsetX(_value:int):void{mOffsetX = _value}
		
		public function get offsetY():int{return mOffsetY}
		public function set offsetY(_value:int):void{mOffsetY = _value}
		
	}
}