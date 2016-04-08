package deferred
{
	
	public class LocalWindForce
	{
		
		private var mElasticy:Number = 0; 
		private var mDampen:Number = 0; 
		
		/**How forcess influences bending. 0 to 1*/
		private var mHardness:Number= 1;
		
		private var mMomentum:Number= 0;
		private var mStrength:Number = 0;
		
		/**Frequency thath impulce of strength is appiled (1 = every frame. 0.1 = 10% chance every frame)*/
		private var mTurbulence:Number = 0.04; 
		/**Max impulce of strenth appiled*/
		private var mTurbulenceStrength:Number = 0.03; 
		private var mAirResistance:Number= 0.04;
		/**Initial seed. there is 0.4 chance that wind will be apilled in first frame*/
		private var mSeed:Number=0.4;
		private var mImpulse:Number=0;
	
		private var mMaxImpulse:Number=1;
		/**Max time in seconds that max of impulse will be appiled*/
		private var mMaxWaveTime:Number = 4;
		private var mGlobalWindWeigth:Number = Math.min((Math.random()*2),1);
		
		public function LocalWindForce(_elasticy:Number = 0.7,_dampen:Number=0.7,_hardness:Number = 0.7)
		{
			mElasticy = _elasticy;
			mDampen = _dampen;
			mHardness = _hardness;
			mMaxImpulse = Math.random() * mTurbulenceStrength //Random 
		}
		public function update(dt:Number):void
		{
			mMomentum -= mStrength/mElasticy;
			mMomentum *= mDampen;
			
			//if(Math.abs(mMomentum) <= mMinimalStrength){ mMomentum = mMinimalStrength}
			mStrength += mMomentum * dt;
			
			calculateImpulse(dt);
			
			mStrength += mImpulse/mHardness; //add local and globalwind with weight

		}
		private function calculateImpulse(dt:Number):void{
			//trace(mStrength);
			
			//Wind impulses starts
			if(mSeed <= mTurbulence){
				
				if(mImpulse >= mMaxImpulse){ // max impulse
					mMaxImpulse = Math.random() * mTurbulenceStrength //Random 
					mSeed = Math.random();
					mImpulse = 0;
				}else{
					mImpulse += mAirResistance* dt; 	//rise up  mImpulse smoothly
				}
				
			}else{
				
				mSeed = Math.random();
			}
		}
		
		/**Give back value between -1 and 1 that represents max and min bend of foliage*/
		public function get strength():Number{
			//treee variance Math.min((Math.random()*6),1)*
			//return Math.max(-1,(Math.min(mStrength,1)));
			return mStrength;
		}
		public function set elasticy(_value:Number):void{mElasticy = _value}
		public function set dampen(_value:Number):void{mDampen = _value}
		public function set hardness(_value:Number):void{mHardness = _value}
	}
}