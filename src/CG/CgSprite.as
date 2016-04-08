package CG 
{
	import starling.core.RenderSupport;
	import starling.display.Sprite;
	import starling.textures.Texture;
	/**
	 * ...
	 * @author 
	 */
	public class CgSprite extends Sprite 
	{
		public static var worldWidth:int;
		public static var worldHeight:int;
		
		protected var previousRenderTarget:Texture;
		
		public function CgSprite(_worldWidth:int, _worldHeight:int) 
		{
			super();
			worldWidth = _worldWidth;
			worldHeight = _worldHeight;
		}
		override public function render(support:RenderSupport, parentAlpha:Number):void
		{
			//We want to render content of this sprite in deferred shading way instead of normal
			//starling rendering
			previousRenderTarget = support.renderTarget;
			support.setRenderTarget(DeferredSample.deferredRenderer.backGroundRT); //render background
			support.clear();
			
			super.render(support,parentAlpha);
			support.setRenderTarget(previousRenderTarget);
			
			DeferredSample.deferredRenderer.render(support);

		}
	}

}