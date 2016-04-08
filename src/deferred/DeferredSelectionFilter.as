package deferred
{
	
	import starling.utils.Color;
	
	public class DeferredSelectionFilter
	{
		private var mColor:uint;
		public var mSize:int;
		public var color:Vector.<Number> = new <Number>[0,0,0,0];
		
		
		public function DeferredSelectionFilter(_color:uint,_size:int=3)
		{
			mColor = _color;
			mSize = _size;
			color[0] = Color.getRed(mColor)/255;
			color[1] = Color.getGreen(mColor)/255;
			color[2] = Color.getBlue(mColor)/255;
			color[3] = 1;
			
			
		}
	}
}