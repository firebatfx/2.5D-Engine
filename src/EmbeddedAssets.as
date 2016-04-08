package
{
	public class EmbeddedAssets
	{
		//Alas
		[Embed(source="../Assets/SampleAtlas.png")]
		public static const SampleAtlas:Class;
		[Embed(source="../Assets/SampleAtlas.xml", mimeType="application/octet-stream")]
		public static const SampleAtlasXml:Class;
		
		//LUTs
		[Embed(source="../Assets/LUT_standard.png")]
		public static const LUT_standard:Class;
		//Vignette
		[Embed(source="../Assets/Winieta2.png")]
		public static const Winieta2:Class;
		
	}
}