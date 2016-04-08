package
{
	import flash.display.Sprite;
	import flash.events.Event;
	import starling.core.Starling;
	[SWF(frameRate="120" , width="640" , height="480" , backgroundColor="0x111111")]
	/**
	 * ...
	 * @Firebat
	 */
	public class Main extends Sprite 
	{
		private var myStarling:Starling;
		
		public function Main() {
			myStarling = new Starling(DeferredSample, stage,null,null,"auto","standard");
			myStarling.antiAliasing = 4;
			myStarling.showStats = true;
			myStarling.start();	
			myStarling.enableErrorChecking = true;
		}

	}
	
}