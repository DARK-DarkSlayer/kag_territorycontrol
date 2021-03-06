#include "Hitters.as";
#include "Explosion.as";
#include "Knocked.as";

string[] particles = 
{
	"SmallExplosion1.png"
	"SmallExplosion2.png",
	"SmallExplosion3.png",
};

string[] explosion_particles = 
{
	"LargeSmoke"
};

const f32 push_radius = 512.00f;

void onInit(CBlob@ this)
{
	this.Tag("explosive");
	this.maxQuantity = 500;
}

void DoExplosion(CBlob@ this)
{
	CRules@ rules = getRules();
	if (!shouldExplode(this, rules))
	{
		addToNextTick(this, rules, DoExplosion);
		return;
	}
	
	f32 random = XORRandom(8);
	f32 intensity = this.getQuantity() / f32(this.maxQuantity);	
	
	this.set_f32("map_damage_radius", (16.0f + random));
	this.set_f32("map_damage_ratio", 0.50f);
	
	Explode(this, 1024.0f * intensity, 500.0f * intensity);
	
	Vec2f pos = this.getPosition();
	CMap@ map = getMap();
	
	SetScreenFlash(255, 255, 255, 255, 3);
	Sound::Play("Fireboom_Boom", this.getPosition(), 10.00f, 2.00f - intensity);
	if (intensity > 0.25f) Sound::Play("Fireboom_Boom");
	
	ShakeScreen(666, 666, this.getPosition());

	CBlob@[] blobs;
	f32 radius = 1.00f + (push_radius * intensity);
	if (map.getBlobsInRadius(pos, radius, @blobs))
	{
		for (int i = 0; i < blobs.length; i++)
		{		
			CBlob@ blob = blobs[i];
			if (blob is null || blob.getShape() is null)
			{
				continue;
			}
			
			if (blob !is null && !blob.getShape().isStatic()) 
			{
				Vec2f dir = blob.getPosition() - pos;
				f32 dist = dir.Length();
				dir.Normalize();
				
				f32 mod = Maths::Sqrt(Maths::Clamp(dist / radius, 0, 1));
				blob.AddForce(dir * blob.getRadius() * 75 * mod);
				SetKnocked(blob, 150 * mod);
			}
		}
	}
	
	if (isServer())
	{				
		CBlob@ boom = server_CreateBlobNoInit("nukeexplosion");
		if (boom !is null)
		{
			boom.setPosition(this.getPosition());
			boom.set_u8("boom_start", 0);
			boom.set_u8("boom_end", 5 + (100 * intensity));
			boom.set_u8("boom_frequency", 1);
			boom.set_u32("boom_delay", 0);
			boom.set_u32("flash_delay", 0);
			boom.Tag("no fallout");
			boom.Tag("no flash");
			boom.Tag("no mithril");
			boom.set_string("custom_explosion_sound", "Fireboom_Boom");
			boom.Init();
		}
	}
	
	if (isClient())
	{
		const u32 count = 200 + (1000 * intensity);
		const f32 seg = 360.00f / count;
		
		for (int i = 0; i < count; i++)
		{
			Vec2f dir = Vec2f(Maths::Cos(i * seg), Maths::Sin(i * seg));
			Vec2f ppos = (pos + dir * 4.00f) + getRandomVelocity(0, 1, 360);
			f32 vel = (XORRandom(200) / (10.00f + XORRandom(10))) * 0.50f;
		
			string filename = CFileMatcher(explosion_particles[XORRandom(explosion_particles.size())]).getFirst();
	
			CParticle@ p = ParticleAnimated(filename, this.getPosition(), dir * vel, float(XORRandom(360)), 2.0f, 5 + XORRandom(10), 0.01f, true);
			if (p !is null)
			{
				p.growth = 0.01f;
				p.velocity = dir * vel;
				p.collides = false;
				p.damping = 0.90f + (XORRandom(40) * 0.0025f);
			}
		}
		
		this.getSprite().Gib();
	}
	
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)
{
	if (isServer())
	{
		if (blob !is null ? !blob.isCollidable() : !solid) return;
		f32 vellen = this.getOldVelocity().Length();

		if (vellen > 3.0f)
		{
			this.server_Die();
		}
	}
}

void onDie(CBlob@ this)
{
	if (this.getQuantity() == 0) { return; }
	DoExplosion(this);
}
