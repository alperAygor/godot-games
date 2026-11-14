class_name QualityTiers
extends RefCounted

## Kalite kademeleri — tek yer. Bütçeyi aşan efekt KAPATILIR, ucuz taklitle değiştirilmez.
##
##   HIGH   : alan derinliği (ön+arka), parlama, 4096 yumuşak gölge, ışık hüzmeleri, MSAA 4x, yansıma sondası
##   MEDIUM : alan derinliği (yalnız arka, düşük kalite), parlama, 2048 gölge, hüzmeler, MSAA 2x
##   LOW    : alan derinliği yok, parlama yok, 1024 sert gölge, hüzme yok, MSAA yok (FXAA)

enum Tier { LOW, MEDIUM, HIGH }

const TIER_NAMES: PackedStringArray = ["low", "medium", "high"]


static func apply(tier: int, view: RoomView) -> void:
	var env: Environment = view.environment
	var cam: DioramaCamera = view.camera_rig
	var sun: DirectionalLight3D = view.sun
	var vp: Viewport = view.get_viewport()
	match tier:
		Tier.HIGH:
			cam.set_dof(true, true)
			RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_MEDIUM, true)
			RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_CIRCLE)
			env.glow_enabled = true
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			sun.shadow_blur = 1.6
			view.shafts.set_enabled(true)
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			if view.reflection_probe != null:
				view.reflection_probe.visible = true
		Tier.MEDIUM:
			cam.set_dof(true, false)
			RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_LOW, false)
			env.glow_enabled = true
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			sun.shadow_blur = 1.2
			view.shafts.set_enabled(true)
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			if view.reflection_probe != null:
				view.reflection_probe.visible = true
		_:
			cam.set_dof(false, false)
			env.glow_enabled = false
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			sun.shadow_blur = 1.0
			view.shafts.set_enabled(false)
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			if view.reflection_probe != null:
				view.reflection_probe.visible = false
