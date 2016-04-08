package 
{
	import CG.Camera;
	import CG.CgBody;
	import CG.CgSprite;
	import deferred.DeferredImage;
	import deferred.DeferredLight;
	import deferred.DeferredLightLayer;
	import deferred.DeferredMovieClip;
	import deferred.DeferredRenderer;
	import deferred.DeferredTexture;
	import flash.geom.Point;
	import starling.display.Sprite;
	import starling.events.Event;
	import starling.utils.AssetManager;
	import starling.core.Starling;
	
	/**
	 * ...
	 * @Firebat
	 */
	public class DeferredSample extends Sprite 
	{
		
		
		public static var deferredRenderer:DeferredRenderer;
		
		private var mAssets:AssetManager;
		private var mCamera:Camera
		private var mWorldSprite:CgSprite
		private var mDeferredLightLayer:DeferredLightLayer;
		private var mDebugSprite:Sprite;
		
		public function DeferredSample() 
		{
			super();
			this.addEventListener(starling.events.Event.ADDED_TO_STAGE , LoadTextures);
			
		}
		private function LoadTextures(event:Event):void
		{
			mAssets = new AssetManager();
			mAssets.enqueue(EmbeddedAssets);
			mAssets.loadQueue(function(ratio:Number):void{
				if(ratio == 1){
					InitializeWorld();
				}
			});
			
		}
		private function InitializeWorld():void {
			//Create World Sprite that will hold on all objects in game
			//It will render all starling display object normally, except cgBodies with attached Deffered Image/MovieClip
			//that will be rendered in deferred way
			mWorldSprite = new CgSprite(1000, 1000);
			this.addChild(mWorldSprite);
			
			//On this sprite debug view will be rendered
			mDebugSprite = new Sprite();
			//Isometric camera class with helper functions and transformation matrix
			mCamera = new Camera(mWorldSprite);
			//Main renderer class
			deferredRenderer = new DeferredRenderer(mWorldSprite, mWorldSprite,mDebugSprite);
			
			//This sprite will hold generated lighting,lut's, and vignette
			mDeferredLightLayer = new DeferredLightLayer(deferredRenderer.diffuseRT, deferredRenderer.lightMapRT, mAssets);
			this.addChild(mDeferredLightLayer);
			this.addChild(mDebugSprite);
			
			//*******************************************
			//example teapot
			var teapot:CgBody = new CgBody();
			var teapotTexture:DeferredTexture= new DeferredTexture(mAssets.getTexture("Teapot01"), mAssets.getTexture("Teapot01_n"), mAssets.getTexture("Teapot01_h"));
			//_depth 1 means that object will take one tile (Camera.TILE_HEIGHT) in depth
			var teapotImage:DeferredImage = new DeferredImage(teapotTexture,5);
			teapot.addChild(teapotImage);
			mWorldSprite.addChild(teapot);
			//*******************************************
			//caordinates in screen space
			teapot.x = 30;
			teapot.y = 40;
			teapot.z = 20;
			//*******************************************
			//Or optionally you can go with world 3d caordinates and project them to screen space 
			//like that:
			
			/*var worldX:int = 30;
			var worldY:int = 40;
			var worldZ:int = 20;
			
			var _point:Point = Camera.worldToIsometric(worldX, worldY, worldZ);
			teapot.x = _point.x;
			teapot.y = _point.y;
			teapot.z = worldZ* Math.SQRT2/2; <---- Math.SQRT2/2 is formula for diagonal of world (vertical line after projection) in dimetric projection*/
			//*******************************************
			//*******************************************
			//example teapot 2
			var teapot2:CgBody = new CgBody();
			var teapotTexture2:DeferredTexture= new DeferredTexture(mAssets.getTexture("Teapot01"), mAssets.getTexture("Teapot01_n"), mAssets.getTexture("Teapot01_h"));
			//_depth 1 means that object will take one tile (Camera.TILE_HEIGHT) in depth
			var teapotImage2:DeferredImage = new DeferredImage(teapotTexture2,2);
			teapot2.addChild(teapotImage2);
			mWorldSprite.addChild(teapot2);
			//*******************************************
			//caordinates in screen space
			teapot2.x = 200;
			teapot2.y = 40;
			teapot2.z = 23;
			teapot2.scaleX = teapot2.scaleY = 0.8;
			teapot2.color = 0xF297E4;
			//*******************************************
			//*******************************************
			//example translucent movie clip
			var effect:CgBody = new CgBody();
			var effectsMovieClip:DeferredMovieClip = new DeferredMovieClip(mAssets.getTextures("SmallLanternEnergy_"), 24, 0, 0.8, true);
			effect.addChild(effectsMovieClip);
			//add to juggler as normal movie clip
			Starling.juggler.add(effectsMovieClip);
			//add to world
			mWorldSprite.addChild(effect);

			//*********************************
			//caordinates in screen space
			effect.x = 100;
			effect.y = 40;
			effect.z = 20;
			
			//*******************************************
			//*******************************************
			//example light
			var lightCgBody:CgBody = new CgBody();
			var light:DeferredLight = new DeferredLight(1024, 1.5, 0xE9F830);
			lightCgBody.addChild(light);
			mWorldSprite.addChild(lightCgBody);
		}
		
	}

}