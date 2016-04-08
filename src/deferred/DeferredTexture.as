package deferred
{
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import starling.textures.SubTexture;
	import starling.textures.Texture;
	import starling.utils.VertexData;
	
	public class DeferredTexture extends Texture
	{
		
		private var mDiffuse:Texture;
		private var mNormal:Texture;
		private var mDepth:Texture;
		
		/**UV offset of normal and depth sector*/
		private var mNormalUvOffset:Point = new Point(0, 0);
		private var mDepthUvOffset:Point = new Point(0, 0);
		
		/**Indicates if normal and depth map should be generated in fly*/
		public var isFlat:Boolean;
		
		public function DeferredTexture(_diffuse:Texture, _normal:Texture = null, _depth:Texture = null)
		{
			mDiffuse = _diffuse;
			mNormal = _normal;
			mDepth = _depth;
			
			if (_normal == null || _depth == null)
			{
				isFlat = true;
			}
			else
			{
				if (mDiffuse.base != mNormal.base || mNormal.base != mDepth.base || mDiffuse.base != mDepth.base)
				{
					throw new ArgumentError("Diffuse, normal and deptha map must be at the same atlas");
				}
				if (!(mDiffuse is SubTexture) || !(mNormal is SubTexture) || !(mDepth is SubTexture))
				{
					throw new ArgumentError("Deffered texture is operating only on subTextures");
				}
				if (mDiffuse.width != mNormal.width || mNormal.width != mDepth.width || mDepth.width != mDiffuse.width || mDiffuse.height != mNormal.height || mNormal.height != mDepth.height || mDepth.height != mDiffuse.height)
				{
					throw new ArgumentError("Diffuse, normal, and deptha map textures must be at the same size");
				}
				
				var dRegion:Rectangle = (mDiffuse as SubTexture).region;
				mNormalUvOffset.setTo((mNormal as SubTexture).region.x - dRegion.x, (mNormal as SubTexture).region.y - dRegion.y);
				mDepthUvOffset.setTo((mDepth as SubTexture).region.x - dRegion.x, (mDepth as SubTexture).region.y - dRegion.y);
				
				mNormalUvOffset.x = mNormalUvOffset.x / mDiffuse.root.width; //clamp to 0-1
				mNormalUvOffset.y = mNormalUvOffset.y / mDiffuse.root.height;
				
				mDepthUvOffset.x = mDepthUvOffset.x / mDiffuse.root.width; //clamp to 0-1
				mDepthUvOffset.y = mDepthUvOffset.y / mDiffuse.root.height;
				isFlat = false;
			}
		
		}
		
		/*-----------------------
		   Overrides
		   -----------------------*/
		public function get normalUvOffset():Point
		{
			return mNormalUvOffset;
		}
		
		public function get depthUvOffset():Point
		{
			return mDepthUvOffset;
		}
		
		override public function get width():Number
		{
			return mDiffuse.width;
		}
		
		override public function get height():Number
		{
			return mDiffuse.height;
		}
		
		/** @inheritDoc */
		override public function adjustVertexData(vertexData:VertexData, vertexID:int, count:int):void
		{
			mDiffuse.adjustVertexData(vertexData, vertexID, count);
		}
		
		/** @inheritDoc */
		override public function adjustTexCoords(texCoords:Vector.<Number>, startIndex:int = 0, stride:int = 0, count:int = -1):void
		{
			mDiffuse.adjustTexCoords(texCoords, startIndex, stride, count);
		}
		
		/** @inheritDoc */
		override public function get frame():Rectangle  { return mDiffuse.frame; }
		
		public function get diffuse():Texture  { return mDiffuse; }
		
		public function get normal():Texture
		{
			if (mNormal != null)
			{
				return mNormal;
			}
			else
			{
				return mDiffuse;
			}
		}
		
		public function get depth():Texture
		{
			if (mDepth != null)
			{
				return mDepth;
			}
			else
			{
				return mDiffuse;
			}
		}
	}
}