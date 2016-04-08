Deferred shading 2.5d isometric renderer.
====================

<a href="http://s29.postimg.org/9nysctlrr/Deferred_Screen.jpg" target="_blank"><img src="http://s29.postimg.org/9nysctlrr/Deferred_Screen.jpg" alt="" /></a>


This is the stand alone renderer part of game engine. All objects are 2d quads with preRendered normal and depth maps. No batching right now.

------------------------------------------------------------
Starling 1.8 is used as a base 2d renderer. At least STANDARD profile must to be set up (MRT needed).

Render engine in motion: [here](https://www.youtube.com/watch?v=H7WlGpn_W2k&feature=youtu.be)

Strongly based on [StarlingRendererPlus]( https://github.com/Varnius/StarlingRendererPlus)

------------------------------------------------------------
<b>Note1</b>:

Depth property explanation:

<a href="http://s14.postimg.org/8gzlg7hsh/Depth.jpg" target="_blank"><img src="http://s14.postimg.org/8gzlg7hsh/Depth.jpg" alt="" /></a>


<b>Note2</b>:

1D Lut color balance workflow:

<a href="http://s9.postimg.org/mhzs0i97j/Luts_Workflow.jpg" target="_blank"><img src="http://s9.postimg.org/mhzs0i97j/Luts_Workflow.jpg" alt="" /></a>


<b>Note3</b>:
There are 2 changes in starling RenderSupport class:

1.in assembleAgal function, version of agal is changed from defoult 1 to 2

 	        public static function assembleAgal(vertexShader:String, fragmentShader:String,
                                            resultProgram:Program3D=null):Program3D
        {
            if (resultProgram == null) 
            {
                var context:Context3D = Starling.context;
                if (context == null) throw new MissingContextError();
                resultProgram = context.createProgram();
            }
            
            resultProgram.upload(
                sAssembler.assemble(Context3DProgramType.VERTEX, vertexShader,2), //changed by Firebat version of agal from 1 to 2
                sAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentShader,2));
            
            return resultProgram;
        }



2. There is added function renderTargets:

		public function setRenderTargets(targets:Vector.<Texture>, antiAliasing:int=0, enableDepthAndStencil:Boolean=true):void 
		{
			renderTarget = targets[0];
			mRenderTargets = targets;
			applyClipRect();
			
			var le:int = mRenderTargets.length;
			var context:Context3D = Starling.context;
			
			for(var i:int = 0; i < le; i++)
			{
				// All render targets with colorOutputIndex > 0 must be reset to null before switching to backbuffer
				// New render target could be a texture again and not backbuffer, but we should still reset it
				
				if(i != 0 || targets[i] != null)
				{
					//trace(targets[i] +"<--------multi");
					context.setRenderToTexture(targets[i] ? targets[i].base : null, enableDepthAndStencil, antiAliasing, 0, i);
				}
			}
			
			if(!renderTarget)
			{
				//trace("To back buffer");
				context.setRenderToBackBuffer();
			}
		}