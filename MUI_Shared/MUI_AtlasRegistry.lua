-- AtlasRegistry: Defines TextureAtlas instances for all imported retail textures
-- Each texture file gets its own TextureAtlas with named sub-regions

MUI_AtlasRegistry = {

    -- =============================================
    -- Metal frame border
    -- Source files: 2406979 (256x256), 2406987 (32x128), 2406984 (256x16)
    -- =============================================

	FrameInner = TextureAtlas("frame-inner", 256, 256, 256, 256, {
		InnerCornerBottomLeft  = { w = 8, h = 8, l = 0.687500, r = 0.750000, t = 0.539062, b = 0.601562 },
		InnerCornerBottomRight = { w = 8, h = 8, l = 0.750000, r = 0.812500, t = 0.539062, b = 0.601562 },
	}),
	
	FrameInnerVertical = TextureAtlas("frame-inner-vertical", 64, 256, 64, 256, {
		InnerLeft = { w = 3, h = 256, l = 0.484375, r = 0.531250, t = 0.000000, b = 1.000000 },
		InnerRight = { w = 3, h = 256, l = 0.562500, r = 0.609375, t = 0.000000, b = 1.000000 },
	}),
	
	FrameInnerHorizontal = TextureAtlas("frame-inner-horizontal", 256, 128, 256, 128, {
		InnerBottom = { w = 256, h = 3, l = 0.000000, r = 1.000000, t = 0.867188, b = 0.890625 },
		-- TopTileStreaks: the metallic streak band under the title bar
		-- (retail _UI-Frame-TopTileStreaks, same 256x128 sheet / FDID 1723833).
		TopTileStreaks = { w = 256, h = 43, l = 0.000000, r = 1.000000, t = 0.007812, b = 0.343750 },
	}),

    FrameMetalCorners = TextureAtlas("frame-metal-corners", 512, 512, 512, 512, {
		CornerTopLeftPortrait 	   = { w = 150, h = 150, l = 0.001953, r = 0.294922, t = 0.298828, b = 0.591797 },
		CornerTopLeftPortraitSmall = { w = 150, h = 150, l = 0.001953, r = 0.294922, t = 0.595703, b = 0.888671 },
        CornerTopLeft         	   = { w = 150, h = 150, l = 0.001953, r = 0.294922, t = 0.001953, b = 0.294922 },
        CornerTopRight        	   = { w = 150, h = 150, l = 0.298828, r = 0.591797, t = 0.001953, b = 0.294922 },
        CornerBottomLeft      	   = { w = 64,  h = 64,  l = 0.298828, r = 0.423828, t = 0.298828, b = 0.423828 },
        CornerBottomRight     	   = { w = 64,  h = 64,  l = 0.427734, r = 0.552734, t = 0.298828, b = 0.423828 },
        CornerTopRightDouble  	   = { w = 150, h = 150, l = 0.595703, r = 0.888672, t = 0.001953, b = 0.294922 },
    }),

    FrameMetalEdgesTB = TextureAtlas("frame-metal-vertical", 64, 256, 64, 256, {
        EdgeTop    = { w = 64, h = 150, l = 0.000000, r = 1.000000, t = 0.003906, b = 0.589844 },
        EdgeBottom = { w = 32, h = 64,  l = 0.000000, r = 0.500000, t = 0.597656, b = 0.847656 },
    }),

    FrameMetalEdgesLR = TextureAtlas("frame-metal-horizontal", 512, 32, 512, 32, {
        EdgeLeft  = { w = 150, h = 32, l = 0.001953, r = 0.294922, t = 0.000000, b = 1.000000 },
        EdgeRight = { w = 150, h = 32, l = 0.298828, r = 0.591797, t = 0.000000, b = 1.000000 },
    }),
	
	FrameBossPortrait = TextureAtlas("frame-bossportrait", 512, 2048, 512, 2048, {
		Nineslice 		  = { w = 432, h = 380, l = 0.001953, r = 0.845703, t = 0.494629, b = 0.680176 },
		Background		  = { w = 398, h = 488, l = 0.001953, r = 0.779297, t = 0.042480, b = 0.280762 },
		Tile 		 	  = { w = 24,  h = 36,  l = 0.000000, r = 0.046875, t = 0.023926, b = 0.041504 },
		Divider			  = { w = 400, h = 74,  l = 0.003906, r = 0.785156, t = 0.686523, b = 0.722656 },
		DividerMiddleTile = { w = 32,  h = 46,  l = 0.000000, r = 0.062500, t = 0.000977, b = 0.023438 },
	}),

	ButtonRed = TextureAtlas("button-red", 512, 512, 512, 512, {
		RightNormal          = { w = 292, h = 128, l = 0.000000, r = 0.570312, t = 0.000000, b = 0.250000 },
		LeftNormal           = { w = 114, h = 128, l = 0.570312, r = 0.792969, t = 0.000000, b = 0.250000 },
		CenterNormal         = { w =  64, h = 128, l = 0.792969, r = 0.917969, t = 0.000000, b = 0.250000 },
		RightPressed         = { w = 292, h = 128, l = 0.000000, r = 0.570312, t = 0.250000, b = 0.500000 },
		LeftPressed          = { w = 114, h = 128, l = 0.570312, r = 0.792969, t = 0.250000, b = 0.500000 },
		CenterPressed        = { w =  64, h = 128, l = 0.792969, r = 0.917969, t = 0.250000, b = 0.500000 },
		RightDisabled        = { w = 292, h = 128, l = 0.000000, r = 0.570312, t = 0.500000, b = 0.750000 },
		LeftDisabled         = { w = 114, h = 128, l = 0.570312, r = 0.792969, t = 0.500000, b = 0.750000 },
		CenterDisabled       = { w =  64, h = 128, l = 0.792969, r = 0.917969, t = 0.500000, b = 0.750000 },
		Highlight            = { w = 441, h = 128, l = 0.000000, r = 0.861328, t = 0.750000, b = 1.000000 },
	}),

	ButtonRedControl = TextureAtlas("button-red-control", 256, 128, 256, 128, {
		Highlight = { w = 36, h = 38, l = 0.449219, r = 0.589844, t = 0.007812, b = 0.304688 },

		ExitNormal = { w = 36, h = 38, l = 0.152344, r = 0.292969, t = 0.007812, b = 0.304688 },
		ExitPressed = { w = 36, h = 38, l = 0.152344, r = 0.292969, t = 0.632812, b = 0.929688 },
		ExitDisabled = { w = 36, h = 38, l = 0.152344, r = 0.292969, t = 0.320312, b = 0.617188 },
	}),

	CheckboxMinimal = TextureAtlas("checkbox-minimal", 64,64,64,64, {
		Background = { w = 30, h = 29, l = 0.015625, r = 0.484375, t = 0.015625, b = 0.468750},
		CheckMark = { w = 30, h = 29, l = 0.015625, r = 0.484375, t = 0.500000, b = 0.953125 },
		CheckMarkDisabled = { w = 30, h = 29, l = 0.515625, r = 0.984375, t = 0.015625, b = 0.468750 },
	}),

	SliderBarMinimal = TextureAtlas("sliderbar-minimal", 32,128,32,128, {
		Left = { w = 11, h = 17, l = 0.437500, r = 0.781250, t = 0.320312, b = 0.453125 },
		Right = { w = 11, h = 17, l = 0.031250, r = 0.375000, t = 0.484375, b = 0.617188 },
		Middle = { w = 1, h = 17, l = 0.000000, r = 0.031250, t = 0.007812, b = 0.140625 },
		Button = { w = 20, h = 19, l = 0.031250, r = 0.656250, t = 0.156250, b = 0.304688 },
		ButtonLeft = { w = 11, h = 19, l = 0.031250, r = 0.375000, t = 0.320312, b = 0.468750 },
		ButtonRight = { w = 9, h = 18, l = 0.031250, r = 0.312500, t = 0.632812, b = 0.773438 },
	}),

	EditBoxSearch = TextureAtlas("editbox-search", 256, 64, 256, 64, {
		BorderLeft   = { w = 16,  h = 40, l = 0.000000, r = 0.062500, t = 0.000000, b = 0.620000 },
		BorderRight  = { w = 16,  h = 40, l = 0.062500, r = 0.125000, t = 0.000000, b = 0.620000 },
		BorderMiddle = { w = 224, h = 40, l = 0.125000, r = 1.000000, t = 0.000000, b = 0.620000 },
		SearchIcon   = { w = 24,  h = 24, l = 0.000000, r = 0.093750, t = 0.625000, b = 1.000000 },
		ClearButton  = { w = 20,  h = 20, l = 0.093750, r = 0.171875, t = 0.625000, b = 0.937500 },
	}),
	
	ScrollbarMinimalProportional = TextureAtlas("scrollbar-minimal-proportional", 128,64,128,64, {
		TrackTop =  { w = 8, h = 8, l = 0.164062, r = 0.226562, t = 0.609375, b = 0.734375 },
		TrackBottom = { w = 8, h = 8, l = 0.085938, r = 0.148438, t = 0.765625, b = 0.890625 },
		
		ArrowTop = { w = 17, h = 11, l = 0.687500, r = 0.820312, t = 0.015625, b = 0.187500 },
		ArrowTopOver = { w = 17, h = 11, l = 0.390625, r = 0.523438, t = 0.218750, b = 0.390625 },
		ArrowTopDown = { w = 17, h = 11, l = 0.835938, r = 0.968750, t = 0.015625, b = 0.187500 },
		
		ArrowBottom = { w = 17, h = 11, l = 0.242188, r = 0.375000, t = 0.812500, b = 0.984375 },
		ArrowBottomOver =  { w = 17, h = 11, l = 0.539062, r = 0.671875, t = 0.015625, b = 0.187500 },
		ArrowBottomDown =  { w = 17, h = 11, l = 0.390625, r = 0.523438, t = 0.015625, b = 0.187500 },
		
		ArrowEnd 	 = { w = 17, h = 17, l = 0.242188, r = 0.375000, t = 0.015625, b = 0.28125 },
		ArrowEndOver = { w = 17, h = 17, l = 0.242188, r = 0.375000, t = 0.015625, b = 0.28125 },
		ArrowEndDown = { w = 17, h = 17, l = 0.242188, r = 0.375000, t = 0.015625, b = 0.28125 },
	}),
	
	ScrollbarMinimalVertical = TextureAtlas("scrollbar-minimal-vertical", 64,1024,64,512, {
		TrackMiddle =  { w = 8, h = 1, l = 0.015625, r = 0.140625, t = 0.000000, b = 0.000977 },
	}),
	
	ScrollbarMinimalSmallProportional = TextureAtlas("scrollbar-minimal-small-proportional", 64,64,64,64, {
		ThumbTop		= { w = 8, h = 8, l = 0.312500, r = 0.437500, t = 0.843750, b = 0.968750 },
		ThumbBottom		=  { w = 8, h = 8, l = 0.609375, r = 0.734375, t = 0.484375, b = 0.609375 },
		
		ThumbTopOver	= { w = 8, h = 8, l = 0.468750, r = 0.593750, t = 0.843750, b = 0.968750 },
		ThumbBottomOver =  { w = 8, h = 8, l = 0.312500, r = 0.437500, t = 0.687500, b = 0.812500 },
		
		ThumbTopDown	= { w = 8, h = 8, l = 0.468750, r = 0.593750, t = 0.687500, b = 0.812500 },
		ThumbBottomDown =  { w = 8, h = 8, l = 0.765625, r = 0.890625, t = 0.484375, b = 0.609375 },
	}),
	
	ScrollbarMinimalSmallVertical = TextureAtlas("scrollbar-minimal-small-vertical", 64,1024,64,512, {
		ThumbMiddle	    = { w = 8, h = 715, l = 0.484375, r = 0.609375, t = 0.000977, b = 0.699219 },
		ThumbMiddleOver = { w = 8, h = 715, l = 0.328125, r = 0.453125, t = 0.000977, b = 0.699219 },
		ThumbMiddleDown = { w = 8, h = 715, l = 0.171875, r = 0.296875, t = 0.000977, b = 0.699219 },
	}),
	
	TabOptions = TextureAtlas("tab-options", 32, 32, 32, 32, {
      TabLeft         = { w = 7,  h = 23, l = 0.000000, r = 0.218750, t = 0.000000, b = 0.718750 },
      TabMiddle       = { w = 1,  h = 23, l = 0.218750, r = 0.250000, t = 0.000000, b = 0.718750 },
      TabRight        = { w = 7,  h = 23, l = 0.250000, r = 0.468750, t = 0.000000, b = 0.718750 },
      TabLeftActive   = { w = 7,  h = 26, l = 0.468750, r = 0.687500, t = 0.000000, b = 0.812500 },
      TabMiddleActive = { w = 1,  h = 26, l = 0.687500, r = 0.718750, t = 0.000000, b = 0.812500 },
      TabRightActive  = { w = 7,  h = 26, l = 0.718750, r = 0.937500, t = 0.000000, b = 0.812500 },
	}),

    -- Retail-style frame tabs (bottom of CharacterFrame / ProfessionFrame / TradeSkillFrame
    -- in Dragonflight+). Source: DragonflightUI's uiframetabs (extracted from retail).
    -- 3-slice: Left/Middle/Right. Inactive variant is 36 tall; active (selected) is
    -- 42 tall — selected tabs stick up slightly above the row.
    TabBottom = TextureAtlas("tab-bottom", 64, 256, 64, 256, {
        TabLeft           = { w = 35, h = 36, l = 0.015625, r = 0.562500, t = 0.816406, b = 0.957031 },
        TabMiddle         = { w = 1,  h = 36, l = 0.000000, r = 0.015625, t = 0.175781, b = 0.316406 },
        TabRight          = { w = 37, h = 36, l = 0.015625, r = 0.593750, t = 0.667969, b = 0.808594 },
        TabLeftActive     = { w = 35, h = 42, l = 0.015625, r = 0.562500, t = 0.496094, b = 0.660156 },
        TabMiddleActive   = { w = 1,  h = 42, l = 0.000000, r = 0.015625, t = 0.003906, b = 0.167969 },
        TabRightActive    = { w = 37, h = 42, l = 0.015625, r = 0.593750, t = 0.324219, b = 0.488281 },
    }),
	
	Dropdown = TextureAtlas("dropdown", 512,512,512,512, {
			
		Bg = { w = 136, h = 136, l = 0.357422, r = 0.623047, t = 0.001953, b = 0.267578 },
		
		ItemHoverL    = { w = 6,  h = 20, l = 0.357422, r = 0.380859, t = 0.271484, b = 0.349609 },
		ItemHoverM    = { w = 8,  h = 20, l = 0.380859, r = 0.412109, t = 0.271484, b = 0.349609 },
		ItemHoverR    = { w = 6,  h = 20, l = 0.412109, r = 0.435547, t = 0.271484, b = 0.349609 },
		
		-- Hover arrow (no slicing needed)
		HoverArrow = { w = 12, h = 5, l = 0.626953, r = 0.673828, t = 0.322266, b = 0.341797 },

		-- Button: normal (three-part: 18+3+18 = 39)
		BtnL = { w = 18, h = 39, l = 0.841797, r = 0.912109, t = 0.001953, b = 0.154297 },
		BtnM = { w = 3,  h = 39, l = 0.912109, r = 0.923828, t = 0.001953, b = 0.154297 },
		BtnR = { w = 18, h = 39, l = 0.923828, r = 0.994141, t = 0.001953, b = 0.154297 },

		-- Button: hover
		BtnHoverL = { w = 18, h = 39, l = 0.783203, r = 0.853516, t = 0.166016, b = 0.318359 },
		BtnHoverM = { w = 3,  h = 39, l = 0.853516, r = 0.865234, t = 0.166016, b = 0.318359 },
		BtnHoverR = { w = 18, h = 39, l = 0.865234, r = 0.935547, t = 0.166016, b = 0.318359 },

		-- Button: pressed
		BtnPressedL = { w = 18, h = 39, l = 0.158203, r = 0.228516, t = 0.673828, b = 0.826172 },
		BtnPressedM = { w = 3,  h = 39, l = 0.228516, r = 0.240234, t = 0.673828, b = 0.826172 },
		BtnPressedR = { w = 18, h = 39, l = 0.240234, r = 0.310547, t = 0.673828, b = 0.826172 },

		-- Button: pressed+hover
		BtnPressHoverL = { w = 18, h = 39, l = 0.314453, r = 0.384766, t = 0.673828, b = 0.826172 },
		BtnPressHoverM = { w = 3,  h = 39, l = 0.384766, r = 0.396484, t = 0.673828, b = 0.826172 },
		BtnPressHoverR = { w = 18, h = 39, l = 0.396484, r = 0.466797, t = 0.673828, b = 0.826172 },

		-- Button: open
		BtnOpenL = { w = 18, h = 39, l = 0.001953, r = 0.072266, t = 0.830078, b = 0.982422 },
		BtnOpenM = { w = 3,  h = 39, l = 0.072266, r = 0.083984, t = 0.830078, b = 0.982422 },
		BtnOpenR = { w = 18, h = 39, l = 0.083984, r = 0.154297, t = 0.830078, b = 0.982422 },

		-- Button: disabled
		BtnDisabledL = { w = 18, h = 39, l = 0.626953, r = 0.697266, t = 0.166016, b = 0.318359 },
		BtnDisabledM = { w = 3,  h = 39, l = 0.697266, r = 0.708984, t = 0.166016, b = 0.318359 },
		BtnDisabledR = { w = 18, h = 39, l = 0.708984, r = 0.779297, t = 0.166016, b = 0.318359 },

		-- Background: nine-slice (7px corners, shadow halo extends outside content)
		-- Corners at TL(17,12) TR(67,12) BL(17,62) BR(67,62) within 90x90 atlas starting at px(1,1)
		BgTopLeft     = { w = 24, h = 19, l = 0.001953, r = 0.095703, t = 0.001953, b = 0.076172 },
		BgTopRight    = { w = 23, h = 19, l = 0.263672, r = 0.353516, t = 0.001953, b = 0.076172 },
		BgBottomLeft  = { w = 24, h = 28, l = 0.001953, r = 0.095703, t = 0.244141, b = 0.353516 },
		BgBottomRight = { w = 23, h = 28, l = 0.263672, r = 0.353516, t = 0.244141, b = 0.353516 },
		BgTop         = { w = 43, h = 19, l = 0.095703, r = 0.263672, t = 0.001953, b = 0.076172 },
		BgBottom      = { w = 43, h = 28, l = 0.095703, r = 0.263672, t = 0.244141, b = 0.353516 },
		BgLeft        = { w = 24, h = 43, l = 0.001953, r = 0.095703, t = 0.076172, b = 0.244141 },
		BgRight       = { w = 23, h = 43, l = 0.263672, r = 0.353516, t = 0.076172, b = 0.244141 },
		BgCenter      = { w = 43, h = 43, l = 0.095703, r = 0.263672, t = 0.076172, b = 0.244141 },		
		
		IconBack = { w = 17, h = 17, l = 0.767578, r = 0.833984, t = 0.357422, b = 0.423828 },
		IconBackDisabled =  { w = 17, h = 17, l = 0.837891, r = 0.904297, t = 0.357422, b = 0.423828 },

		IconNext = { w = 17, h = 17, l = 0.908203, r = 0.974609, t = 0.357422, b = 0.423828 },
		IconNextDisabled = { w = 17, h = 17, l = 0.767578, r = 0.833984, t = 0.462891, b = 0.529297 },

		-- Full 39x39 button squares (for steppers)
		BtnFull         = { w = 39, h = 39, l = 0.841797, r = 0.994141, t = 0.001953, b = 0.154297 },
		BtnHoverFull    = { w = 39, h = 39, l = 0.783203, r = 0.935547, t = 0.166016, b = 0.318359 },
		BtnPressedFull  = { w = 39, h = 39, l = 0.158203, r = 0.310547, t = 0.673828, b = 0.826172 },
		BtnDisabledFull = { w = 39, h = 39, l = 0.626953, r = 0.779297, t = 0.166016, b = 0.318359 },
	}),
	
	Options = TextureAtlas("options", 1024, 1024, 512, 512, {
		ListActive		  = { w = 187, h = 21,  l = 0.589844, r = 0.772461, t = 0.000977, b = 0.021000 },
		ListHover		  = { w = 187, h = 21,  l = 0.774414, r = 0.957031, t = 0.000977, b = 0.021000 },
		HorizontalDivider = { w = 630, h = 1,   l = 0.000977, r = 0.616211, t = 0.143555, b = 0.144531 },
		InnerFrame		  = { w = 886, h = 618, l = 0.000977, r = 0.866211, t = 0.146484, b = 0.750000 },
	}),

	OptionsCategoryHeaders = TextureAtlas("options-category-headers", 512, 512, 512, 512, {
		CategoryHeader1 = { w = 199, h = 144, l = 0.000000, r = 0.388672, t = 0.000000, b = 0.281250 },
		CategoryHeader2 = { w = 199, h = 144, l = 0.388672, r = 0.777344, t = 0.000000, b = 0.281250 },
		CategoryHeader3 = { w = 199, h = 144, l = 0.000000, r = 0.388672, t = 0.281250, b = 0.562500 },
	}),
	
	MicroMenu = TextureAtlas("skin\\micromenu\\micromenu", 512, 512, 512, 512, {
		ButtonBGUp               = { w =  64, h =  82, l = 0.000000, r = 0.125000, t = 0.000000, b = 0.160156 },
		ButtonBGDown             = { w =  64, h =  82, l = 0.125000, r = 0.250000, t = 0.000000, b = 0.160156 },
		ButtonHighlightAlert     = { w =  64, h =  82, l = 0.250000, r = 0.375000, t = 0.000000, b = 0.160156 },
		ProfessionsUp            = { w =  64, h =  82, l = 0.375000, r = 0.500000, t = 0.000000, b = 0.160156 },
		ProfessionsDown          = { w =  64, h =  82, l = 0.500000, r = 0.625000, t = 0.000000, b = 0.160156 },
		ProfessionsDisabled      = { w =  64, h =  82, l = 0.625000, r = 0.750000, t = 0.000000, b = 0.160156 },
		ProfessionsMouseover     = { w =  64, h =  82, l = 0.750000, r = 0.875000, t = 0.000000, b = 0.160156 },
		SpellbookUp                 = { w =  64, h =  82, l = 0.875000, r = 1.000000, t = 0.000000, b = 0.160156 },
		SpellbookDown               = { w =  64, h =  82, l = 0.000000, r = 0.125000, t = 0.160156, b = 0.320312 },
		SpellbookDisabled           = { w =  64, h =  82, l = 0.125000, r = 0.250000, t = 0.160156, b = 0.320312 },
		SpellbookMouseover          = { w =  64, h =  82, l = 0.250000, r = 0.375000, t = 0.160156, b = 0.320312 },
		TalentsUp                = { w =  64, h =  82, l = 0.375000, r = 0.500000, t = 0.160156, b = 0.320312 },
		TalentsDown              = { w =  64, h =  82, l = 0.500000, r = 0.625000, t = 0.160156, b = 0.320312 },
		TalentsDisabled          = { w =  64, h =  82, l = 0.625000, r = 0.750000, t = 0.160156, b = 0.320312 },
		TalentsMouseover         = { w =  64, h =  82, l = 0.750000, r = 0.875000, t = 0.160156, b = 0.320312 },
		AchievementsUp           = { w =  64, h =  82, l = 0.875000, r = 1.000000, t = 0.160156, b = 0.320312 },
		AchievementsDown         = { w =  64, h =  82, l = 0.000000, r = 0.125000, t = 0.320312, b = 0.480469 },
		AchievementsDisabled     = { w =  64, h =  82, l = 0.125000, r = 0.250000, t = 0.320312, b = 0.480469 },
		AchievementsMouseover    = { w =  64, h =  82, l = 0.250000, r = 0.375000, t = 0.320312, b = 0.480469 },
		QuestLogUp               = { w =  64, h =  82, l = 0.375000, r = 0.500000, t = 0.320312, b = 0.480469 },
		QuestLogDown             = { w =  64, h =  82, l = 0.500000, r = 0.625000, t = 0.320312, b = 0.480469 },
		QuestLogDisabled         = { w =  64, h =  82, l = 0.625000, r = 0.750000, t = 0.320312, b = 0.480469 },
		QuestLogMouseover        = { w =  64, h =  82, l = 0.750000, r = 0.875000, t = 0.320312, b = 0.480469 },
		GuildUp                  = { w =  64, h =  82, l = 0.875000, r = 1.000000, t = 0.320312, b = 0.480469 },
		GuildDown                = { w =  64, h =  82, l = 0.000000, r = 0.125000, t = 0.480469, b = 0.640625 },
		GuildDisabled            = { w =  64, h =  82, l = 0.125000, r = 0.250000, t = 0.480469, b = 0.640625 },
		GuildMouseover           = { w =  64, h =  82, l = 0.250000, r = 0.375000, t = 0.480469, b = 0.640625 },
		GroupFinderUp            = { w =  64, h =  82, l = 0.375000, r = 0.500000, t = 0.480469, b = 0.640625 },
		GroupFinderDown          = { w =  64, h =  82, l = 0.500000, r = 0.625000, t = 0.480469, b = 0.640625 },
		GroupFinderDisabled      = { w =  64, h =  82, l = 0.625000, r = 0.750000, t = 0.480469, b = 0.640625 },
		GroupFinderMouseover     = { w =  64, h =  82, l = 0.750000, r = 0.875000, t = 0.480469, b = 0.640625 },
		CollectionsUp            = { w =  64, h =  82, l = 0.875000, r = 1.000000, t = 0.480469, b = 0.640625 },
		CollectionsDown          = { w =  64, h =  82, l = 0.000000, r = 0.125000, t = 0.640625, b = 0.800781 },
		CollectionsDisabled      = { w =  64, h =  82, l = 0.125000, r = 0.250000, t = 0.640625, b = 0.800781 },
		CollectionsMouseover     = { w =  64, h =  82, l = 0.250000, r = 0.375000, t = 0.640625, b = 0.800781 },
		AdventureGuideUp         = { w =  64, h =  82, l = 0.375000, r = 0.500000, t = 0.640625, b = 0.800781 },
		AdventureGuideDown       = { w =  64, h =  82, l = 0.500000, r = 0.625000, t = 0.640625, b = 0.800781 },
		AdventureGuideDisabled   = { w =  64, h =  82, l = 0.625000, r = 0.750000, t = 0.640625, b = 0.800781 },
		AdventureGuideMouseover  = { w =  64, h =  82, l = 0.750000, r = 0.875000, t = 0.640625, b = 0.800781 },
		ShopUp                   = { w =  64, h =  82, l = 0.875000, r = 1.000000, t = 0.640625, b = 0.800781 },
		ShopDown                 = { w =  64, h =  82, l = 0.000000, r = 0.125000, t = 0.800781, b = 0.960938 },
		ShopDisabled             = { w =  64, h =  82, l = 0.125000, r = 0.250000, t = 0.800781, b = 0.960938 },
		ShopMouseover            = { w =  64, h =  82, l = 0.250000, r = 0.375000, t = 0.800781, b = 0.960938 },
		GameMenuUp               = { w =  64, h =  82, l = 0.375000, r = 0.500000, t = 0.800781, b = 0.960938 },
		GameMenuDown             = { w =  64, h =  82, l = 0.500000, r = 0.625000, t = 0.800781, b = 0.960938 },
		GameMenuMouseover        = { w =  64, h =  82, l = 0.625000, r = 0.750000, t = 0.800781, b = 0.960938 },
	}),

	XPBar = TextureAtlas("skin\\xpbar\\xpbar", 512, 512, 512, 512, {
		FrameLeft                = { w = 512, h =  34, l = 0.000000, r = 1.000000, t = 0.000000, b = 0.066406 },
		FrameRight               = { w = 512, h =  34, l = 0.000000, r = 1.000000, t = 0.066406, b = 0.132812 },
		BackgroundLeft           = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.132812, b = 0.167969 },
		BackgroundRight          = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.167969, b = 0.203125 },
		FillXPLeft               = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.203125, b = 0.238281 },
		FillXPRight              = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.238281, b = 0.273438 },
		FillRestedLeft           = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.273438, b = 0.308594 },
		FillRestedRight          = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.308594, b = 0.343750 },
		FillRepRedLeft           = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.343750, b = 0.378906 },
		FillRepRedRight          = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.378906, b = 0.414062 },
		FillRepOrangeLeft        = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.414062, b = 0.449219 },
		FillRepOrangeRight       = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.449219, b = 0.484375 },
		FillRepGreenLeft         = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.484375, b = 0.519531 },
		FillRepGreenRight        = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.519531, b = 0.554688 },
		FillRepBlueLeft          = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.554688, b = 0.589844 },
		FillRepBlueRight         = { w = 512, h =  18, l = 0.000000, r = 1.000000, t = 0.589844, b = 0.625000 },
		Pip                      = { w =  20, h =  28, l = 0.000000, r = 0.039062, t = 0.625000, b = 0.679688 },
		FillRepYellow            = { w = 512, h =   9, l = 0.000000, r = 1.000000, t = 0.679688, b = 0.697266 },
	}),
	
	ActionBar = TextureAtlas("skin\\actionbars\\actionbar", 512, 512, 512, 512, {
		IconFrame                = { w =  92, h =  90, l = 0.000000, r = 0.179688, t = 0.000000, b = 0.175781 },
		IconFrameDown            = { w =  92, h =  90, l = 0.179688, r = 0.359375, t = 0.000000, b = 0.175781 },
		IconFrameMouseover       = { w =  92, h =  90, l = 0.359375, r = 0.539062, t = 0.000000, b = 0.175781 },
		IconFrameSlot            = { w = 128, h = 124, l = 0.539062, r = 0.789062, t = 0.000000, b = 0.242188 },
		IconFrameFlash           = { w =  92, h =  90, l = 0.789062, r = 0.968750, t = 0.000000, b = 0.175781 },
		IconFrameBorder          = { w =  92, h =  90, l = 0.000000, r = 0.179688, t = 0.242188, b = 0.417969 },
		PageUpNormal             = { w =  34, h =  28, l = 0.179688, r = 0.246094, t = 0.242188, b = 0.296875 },
		PageUpDown               = { w =  34, h =  28, l = 0.246094, r = 0.312500, t = 0.242188, b = 0.296875 },
		PageUpDisabled           = { w =  34, h =  28, l = 0.312500, r = 0.378906, t = 0.242188, b = 0.296875 },
		PageUpMouseover          = { w =  34, h =  28, l = 0.378906, r = 0.445312, t = 0.242188, b = 0.296875 },
		PageDownNormal           = { w =  34, h =  28, l = 0.445312, r = 0.511719, t = 0.242188, b = 0.296875 },
		PageDownDown             = { w =  34, h =  28, l = 0.511719, r = 0.578125, t = 0.242188, b = 0.296875 },
		PageDownDisabled         = { w =  34, h =  28, l = 0.578125, r = 0.644531, t = 0.242188, b = 0.296875 },
		PageDownMouseover        = { w =  34, h =  28, l = 0.644531, r = 0.710938, t = 0.242188, b = 0.296875 },
		DividerEdgeTop           = { w =  24, h =  28, l = 0.710938, r = 0.757812, t = 0.242188, b = 0.296875 },
		DividerEdgeBottom        = { w =  24, h =  30, l = 0.757812, r = 0.804688, t = 0.242188, b = 0.300781 },
		IconFrameBG              = { w =  92, h =  90, l = 0.804688, r = 0.984375, t = 0.242188, b = 0.417969 },
		DividerCenter            = { w =  24, h =  32, l = 0.000000, r = 0.046875, t = 0.417969, b = 0.480469 },
		
	}),

	ActionBarMainBg = TextureAtlas("skin\\actionbars\\actionbar-main-bg", 128, 128, 128, 128, {
		Left   = { w = 18, h = 104, l = 0.015625, r = 0.156250, t = 0.015625, b = 0.828125 },
		Middle = { w = 66, h = 104, l = 0.156250, r = 0.671875, t = 0.015625, b = 0.828125 },
		Right  = { w = 18, h = 104, l = 0.671875, r = 0.812500, t = 0.015625, b = 0.828125 },
	}),
	
	ListExpand = TextureAtlas("options-list-expand", 128, 128, 128, 128, {
		Left		  = { w = 12, h = 26, l = 0.007812, r = 0.101562, t = 0.656250, b = 0.859375 },
		Right		  = { w = 28, h = 26, l = 0.007812, r = 0.226562, t = 0.437500, b = 0.640625 },
		RightExpanded = { w = 28, h = 26, l = 0.242188, r = 0.460938, t = 0.437500, b = 0.640625 },
		Middle		  = { w = 1,  h = 26, l = 0.000000, r = 0.007812, t = 0.218750, b = 0.421875 },
	}),
	
	CastBar = TextureAtlas("skin\\castbar\\castbar-2x", 1024, 512, 1024, 512, {
		Background		 = { w = 211, h = 13, l = 0.000977, r = 0.413086, t = 0.367188, b = 0.417969 },
		Frame			 = { w = 213, h = 15, l = 0.412109, r = 0.828125, t = 0.001953, b = 0.060547 },
		
		FillingStandard	 = { w = 209, h = 11, l = 0.411133, r = 0.819336, t = 0.515625, b = 0.558594 },
		FullStandard 	 = { w = 212, h = 14, l = 0.418945, r = 0.833008, t = 0.304688, b = 0.359375 },
		FullGlowStandard = { w = 213, h = 15, l = 0.000977, r = 0.416992, t = 0.242188, b = 0.300781 },
		
		FillingChannel   = { w = 209, h = 11, l = 0.000977, r = 0.409180, t = 0.515625, b = 0.558594 },

		FillingCraft	 = { w = 209, h = 11, l = 0.411133, r = 0.819336, t = 0.468750, b = 0.511719 },
		FullCraft		 = { w = 213, h = 15, l = 0.000977, r = 0.416992, t = 0.117188, b = 0.175781 },
		FullGlowCraft	 = { w = 213, h = 15, l = 0.000977, r = 0.416992, t = 0.179688, b = 0.238281 },

		Uninterruptible  = { w = 209, h = 11, l = 0.411133, r = 0.819336, t = 0.750000, b = 0.792969 },
		Interrupted	 	 = { w = 209, h = 11, l = 0.000977, r = 0.409180, t = 0.656250, b = 0.699219 },
		
		Pip			     = { w = 5,   h = 30, l = 0.076172, r = 0.085938, t = 0.796875, b = 0.914062 },
		Shield  		 = { w = 37,  h = 44, l = 0.000977, r = 0.074219, t = 0.796875, b = 0.970703 },
		Textbox			 = { w = 209, h = 28, l = 0.000977, r = 0.410156, t = 0.001953, b = 0.113281 },
	}),
	
	Nameplates1 = TextureAtlas("skin\\nameplates\\nameplates-1", 512, 256, 512, 256, {
		Bar   = { w = 248, h = 20, l = 0.341797, r = 0.826172, t = 0.160156, b = 0.238281 },
		BarBG = { w = 264, h = 38, l = 0.341797, r = 0.857422, t = 0.003906, b = 0.152344 },
	}),
	
	Nameplates2 = TextureAtlas("skin\\nameplates\\nameplates-2", 512, 128, 512, 128, {
		Selected   = { w = 216, h = 18, l = 0.001953, r = 0.423828, t = 0.796875, b = 0.937500 },
		Deselected = { w = 210, h = 12, l = 0.431641, r = 0.841797, t = 0.632812, b = 0.726562 },
	}),
	
	ComboDruid = TextureAtlas("skin\\unitframes\\combo-druid", 512, 512, 512, 512, {
		BGDis	 = { w = 40, h = 40, l = 0.906250, r = 0.984375, t = 0.240234, b = 0.318359 },
		BGActive = { w = 40, h = 40, l = 0.818359, r = 0.896484, t = 0.337891, b = 0.416016 },
		BGShadow = { w = 50, h = 50, l = 0.001953, r = 0.099609, t = 0.486328, b = 0.583984 },
		Icon	 = { w = 28, h = 28, l = 0.906250, r = 0.960938, t = 0.382812, b = 0.437500 },
		BGGlow	 = { w = 72, h = 72, l = 0.818359, r = 0.958984, t = 0.001953, b = 0.142578 },
		RingGlow = { w = 46, h = 46, l = 0.906250, r = 0.996094, t = 0.146484, b = 0.236328 },
		Deplete	 = { w = 30, h = 30, l = 0.818359, r = 0.878906, t = 0.419922, b = 0.478516 },
		Slash	 = { w = 416,h = 246,l = 0.001953, r = 0.814453, t = 0.001953, b = 0.482422 },
		Smoke	 = { w = 42, h = 96, l = 0.818359, r = 0.902344, t = 0.146484, b = 0.333984 },
	}),
	
	ComboRogue = TextureAtlas("skin\\unitframes\\combo-rogue", 1024, 1024, 1024, 1024, {
		BGDis	 = { w = 40, h = 40, l = 0.579102, r = 0.618164, t = 0.124023, b = 0.163086 },
		BGActive = { w = 40, h = 40, l = 0.579102, r = 0.618164, t = 0.000977, b = 0.040039 },
		BGShadow = { w = 50, h = 50, l = 0.506836, r = 0.555664, t = 0.073242, b = 0.122070 },
		Icon	 = { w = 28, h = 28, l = 0.536133, r = 0.563477, t = 0.219727, b = 0.248047 },
		FX		 = { w = 28, h = 28, l = 0.579102, r = 0.606445, t = 0.194336, b = 0.221680 },
		RingGlow = { w = 46, h = 46, l = 0.506836, r = 0.551758, t = 0.172852, b = 0.217773 },
		Slash	 = { w = 516,h = 258,l = 0.000977, r = 0.504883, t = 0.254883, b = 0.506836 },
	}),
	
	QuestTracker = TextureAtlas("skin\\questtracker\\questtracker", 1024, 512, 1024, 512, {
		PrimaryHeader			 = { w = 300, h = 40, l = 0.000977, r = 0.552914, t = 0.470703, b = 0.626953 },
		PrimaryCollapse			 = { w = 18,  h = 19, l = 0.928711, r = 0.963867, t = 0.115234, b = 0.189453 },
		PrimaryCollapsePressed	 = { w = 18,  h = 19, l = 0.883789, r = 0.918945, t = 0.236328, b = 0.310547 },
		PrimaryExpand			 = { w = 18,  h = 19, l = 0.883789, r = 0.918945, t = 0.314453, b = 0.388672 },
		PrimaryExpandPressed	 = { w = 18,  h = 19, l = 0.883789, r = 0.918945, t = 0.392578, b = 0.466797 },
		
		SecondaryHeader			 = { w = 300, h = 30, l = 0.000977, r = 0.552914, t = 0.630859, b = 0.748047 },
		SecondaryCollapse		 = { w = 16,  h = 16, l = 0.965820, r = 0.997070, t = 0.115234, b = 0.177734 },
		SecondaryCollapsePressed = { w = 16,  h = 16, l = 0.920898, r = 0.952148, t = 0.392578, b = 0.455078 },
		SecondaryExpand			 = { w = 16,  h = 16, l = 0.958008, r = 0.989258, t = 0.314453, b = 0.376953 },
		SecondaryExpandPressed	 = { w = 16,  h = 16, l = 0.958008, r = 0.989258, t = 0.380859, b = 0.443359 },
		
		HighlightRed	 = { w = 18, h = 19, l = 0.920898, r = 0.956055, t = 0.314453, b = 0.388672 },
		HighlightYellow  = { w = 16, h = 16, l = 0.588867, r = 0.620117, t = 0.470703, b = 0.533203 },
		
		ObjectiveNub 	 = { w = 19, h = 19, l = 0.954102, r = 0.991211, t = 0.001953, b = 0.076172 },
		ObjectiveFail	 = { w = 19, h = 19, l = 0.915039, r = 0.952148, t = 0.001953, b = 0.076172 },
		
		TrackerCheck 	 = { w = 19, h = 19, l = 0.850586, r = 0.887695, t = 0.115234, b = 0.189453 },
		TrackerCheckGlow = { w = 19, h = 19, l = 0.889648, r = 0.926758, t = 0.115234, b = 0.189453 },
		
		-- Animation effects
		AnimShine 	 = { w = 154, h = 23, l = 0.547852, r = 0.848633, t = 0.115234, b = 0.205078 },
		AnimBarGlow  = { w = 187, h = 28, l = 0.547852, r = 0.913086, t = 0.001953, b = 0.111328 },
		AnimLineGlow = { w = 371, h = 6, l = 0.000977, r = 0.725586, t = 0.751953, b = 0.775391 },
	}),
	
	QuestPoiDefault = TextureAtlas("skin\\questtracker\\poi-default", 512, 256, 512, 256, {
		Bg 				 = { w = 32, h = 32, l = 0.255859, r = 0.380859, t = 0.261719, b = 0.511719 },
		BgFocused 		 = { w = 32, h = 32, l = 0.384766, r = 0.509766, t = 0.261719, b = 0.511719 },
		BgPressed 		 = { w = 32, h = 32, l = 0.255859, r = 0.380859, t = 0.519531, b = 0.769531 },
		BgFocusedPressed = { w = 32, h = 32, l = 0.384766, r = 0.509766, t = 0.003906, b = 0.253906 },
		GlowInner 		 = { w = 32, h = 32, l = 0.001953, r = 0.126953, t = 0.511719, b = 0.761719 },
		GlowOuter 		 = { w = 64, h = 64, l = 0.001953, r = 0.251953, t = 0.003906, b = 0.503906 },
		TurnIn 			 = { w = 32, h = 32, l = 0.255859, r = 0.380859, t = 0.003906, b = 0.253906 },
	}),
	
	QuestPoiRecurring = TextureAtlas("skin\\questtracker\\poi-repeatable", 512, 256, 512, 256, {
		Bg 				 = { w = 32, h = 32, l = 0.384766, r = 0.509766, t = 0.003906, b = 0.253906 },
		BgFocused 		 = { w = 32, h = 32, l = 0.513672, r = 0.638672, t = 0.003906, b = 0.253906 },
		BgPressed 		 = { w = 32, h = 32, l = 0.384766, r = 0.509766, t = 0.261719, b = 0.511719 },
		BgFocusedPressed = { w = 32, h = 32, l = 0.384766, r = 0.509766, t = 0.519531, b = 0.769531 },
		GlowInner		 = { w = 32, h = 32, l = 0.001953, r = 0.126953, t = 0.511719, b = 0.761719 },
		GlowOuter		 = { w = 64, h = 64, l = 0.001953, r = 0.251953, t = 0.003906, b = 0.503906 },
		TurnIn			 = { w = 32, h = 32, l = 0.255859, r = 0.380859, t = 0.519531, b = 0.769531 },
	}),
	
	QuestPoiInProgress = TextureAtlas("skin\\questtracker\\poi-inprogress", 256, 128, 256, 128, {
		DotsYellow = { w = 32, h = 32, l = 0.261719, r = 0.511719, t = 0.007812, b = 0.507812 },
		DotsBrown  = { w = 32, h = 32, l = 0.003906, r = 0.253906, t = 0.007812, b = 0.507812 },
	}),

	-- Quest type glyphs for the POI button (log / tracker) and the quest
	-- log's row tag.
	QuestPoiGlyphs = TextureAtlas("skin\\questtracker\\poi-glyphs", 512, 64, 512, 64, {
		Elite      = { w = 64, h = 64, l = 0.000000, r = 0.125000, t = 0.000000, b = 1.000000 },
		Dungeon    = { w = 50, h = 50, l = 0.128906, r = 0.226562, t = 0.000000, b = 0.781250 },
		Kill       = { w = 32, h = 32, l = 0.230469, r = 0.292969, t = 0.000000, b = 0.500000 },
		Loot       = { w = 32, h = 32, l = 0.296875, r = 0.359375, t = 0.000000, b = 0.500000 },
		TagDungeon = { w = 18, h = 18, l = 0.363281, r = 0.398438, t = 0.000000, b = 0.281250 },
		TagGroup   = { w = 18, h = 18, l = 0.402344, r = 0.437500, t = 0.000000, b = 0.281250 },
		TagPvP     = { w = 18, h = 18, l = 0.441406, r = 0.476562, t = 0.000000, b = 0.281250 },
		TagRaid    = { w = 18, h = 18, l = 0.480469, r = 0.515625, t = 0.000000, b = 0.281250 },
		Dragon     = { w = 64, h = 64, l = 0.519531, r = 0.644531, t = 0.000000, b = 1.000000 },
		Boss       = { w = 32, h = 32, l = 0.648438, r = 0.710938, t = 0.000000, b = 0.500000 },
		SwirlDungeon = { w = 16, h = 17, l = 0.714844, r = 0.746094, t = 0.000000, b = 0.265625 },
		SwirlRaid    = { w = 16, h = 17, l = 0.750000, r = 0.781250, t = 0.000000, b = 0.265625 },
		FocusRing    = { w = 64, h = 64, l = 0.812500, r = 0.937500, t = 0.000000, b = 1.000000 },
	}),

	-- Retail's level-up banner sheet (file 4000331): lines, shadows, glow,
	-- dot and the unlock sub-icons.
	-- Retail's zone story header (questmaplogatlas StoryHeader-BG, the
	-- questlogframe2x divider, Scenarios\ScenarioIcon-Check), 2x art.
	StoryHeader = TextureAtlas("skin\\worldmap\\storyheader", 1024, 256, 1024, 256, {
		Banner  = { w = 304, h = 69, l = 0.000000, r = 0.593750, t = 0.000000, b = 0.539063 },
		Divider = { w = 93,  h = 15, l = 0.597656, r = 0.779297, t = 0.000000, b = 0.117188 },
		Check   = { w = 16,  h = 16, l = 0.597656, r = 0.613281, t = 0.156250, b = 0.218750 },
	}),

	-- Retail's search art: preview rows, selection, result highlight, icon frame.
	Search = TextureAtlas("skin\\common-search", 512, 128, 512, 128, {
		RowBg          = { w = 64,  h = 27, l = 0.000000, r = 0.125000, t = 0.007812, b = 0.218750 },
		Select         = { w = 126, h = 27, l = 0.505859, r = 0.751953, t = 0.234375, b = 0.445312 },
		Highlight      = { w = 126, h = 27, l = 0.001953, r = 0.248047, t = 0.617188, b = 0.828125 },
		HighlightLarge = { w = 256, h = 47, l = 0.001953, r = 0.501953, t = 0.234375, b = 0.601562 },
		IconFrameLarge = { w = 38,  h = 38, l = 0.755859, r = 0.830078, t = 0.234375, b = 0.531250 },
	}),

	-- Retail's achievement alert sheet (the "Achievement Earned!" toast).
	AchievementAlert = TextureAtlas("achievements\\achievement-alerts-sheet", 1024, 1024, 1024, 1024, {
		Background = { w = 310, h = 101, l = 0.625000, r = 0.927734, t = 0.169922, b = 0.268555 },
		Glow       = { w = 400, h = 171, l = 0.000977, r = 0.391602, t = 0.000977, b = 0.167969 },
		Shine      = { w = 67,  h = 85,  l = 0.000977, r = 0.066406, t = 0.845703, b = 0.928711 },
		IconFrame  = { w = 74,  h = 74,  l = 0.107422, r = 0.179688, t = 0.505859, b = 0.578125 },
		Shield     = { w = 63,  h = 56,  l = 0.925781, r = 0.987305, t = 0.304688, b = 0.359375 },
	}),

	LevelUp = TextureAtlas("skin\\levelup\\levelup", 1024, 512, 1024, 512, {
		ShadowLower = { w = 284, h = 296, l = 0.000977, r = 0.278320, t = 0.001953, b = 0.580078 },
		ShadowUpper = { w = 326, h = 103, l = 0.280273, r = 0.598633, t = 0.001953, b = 0.203125 },
		BarGold     = { w = 418, h = 7,   l = 0.500977, r = 0.909180, t = 0.207031, b = 0.220703 },
		BarGreen    = { w = 418, h = 7,   l = 0.500977, r = 0.909180, t = 0.224609, b = 0.238281 },
		BarWhite    = { w = 418, h = 7,   l = 0.500977, r = 0.909180, t = 0.242188, b = 0.255859 },
		GlowGold    = { w = 224, h = 115, l = 0.000977, r = 0.219727, t = 0.583984, b = 0.808594 },
		GlowGreen   = { w = 224, h = 115, l = 0.280273, r = 0.499023, t = 0.207031, b = 0.431641 },
		DotGold     = { w = 21,  h = 22,  l = 0.252930, r = 0.273438, t = 0.662109, b = 0.705078 },
		DotGreen    = { w = 21,  h = 22,  l = 0.252930, r = 0.273438, t = 0.734375, b = 0.777344 },
		IconBook    = { w = 40,  h = 38,  l = 0.221680, r = 0.260742, t = 0.583984, b = 0.658203 },
		IconLock    = { w = 30,  h = 35,  l = 0.221680, r = 0.250977, t = 0.662109, b = 0.730469 },
		IconArrow   = { w = 30,  h = 34,  l = 0.221680, r = 0.250977, t = 0.734375, b = 0.800781 },
		IconBag     = { w = 29,  h = 34,  l = 0.000977, r = 0.029297, t = 0.812500, b = 0.878906 },
	}),

	-- Retail's auction house art (Blizzard_AuctionHouseUI): the chrome sheet
	-- (Interface\AuctionFrame\AuctionHouse, 3046538) and the panel backgrounds
	-- (AuctionHouseBackgrounds, 3054898). w / h are the atlas members' own sizes;
	-- much of the chrome is 2x art, so callers size the pieces themselves.
	AuctionHouse = TextureAtlas("skin\\auctionhouse\\auctionhouse", 1024, 1024, 1024, 1024, {
		ItemHeaderFrame             = { w = 342, h =  72, l = 0.000977, r = 0.668945, t = 0.000977, b = 0.141602 },
		ItemIconEmpty               = { w = 100, h = 100, l = 0.135742, r = 0.233398, t = 0.833008, b = 0.930664 },
		ItemIconBorderGray          = { w = 136, h = 136, l = 0.135742, r = 0.268555, t = 0.428711, b = 0.561523 },
		ItemIconBorderWhite         = { w = 136, h = 136, l = 0.135742, r = 0.268555, t = 0.698242, b = 0.831055 },
		ItemIconBorderGreen         = { w = 136, h = 136, l = 0.000977, r = 0.133789, t = 0.563477, b = 0.696289 },
		ItemIconBorderBlue          = { w = 136, h = 136, l = 0.000977, r = 0.133789, t = 0.428711, b = 0.561523 },
		ItemIconBorderPurple        = { w = 136, h = 136, l = 0.000977, r = 0.133789, t = 0.698242, b = 0.831055 },
		ItemIconBorderOrange        = { w = 136, h = 136, l = 0.135742, r = 0.268555, t = 0.563477, b = 0.696289 },
		ItemIconSmallBorder         = { w =  32, h =  32, l = 0.095703, r = 0.126953, t = 0.967773, b = 0.999023 },
		NavButton                   = { w = 272, h =  64, l = 0.635742, r = 0.901367, t = 0.143555, b = 0.206055 },
		NavButtonHighlight          = { w = 264, h =  42, l = 0.547852, r = 0.805664, t = 0.209961, b = 0.250977 },
		NavButtonSelect             = { w = 264, h =  42, l = 0.286133, r = 0.543945, t = 0.274414, b = 0.315430 },
		NavButtonSecondary          = { w = 266, h =  64, l = 0.286133, r = 0.545898, t = 0.209961, b = 0.272461 },
		NavButtonSecondaryHighlight = { w = 244, h =  42, l = 0.545898, r = 0.784180, t = 0.274414, b = 0.315430 },
		NavButtonSecondarySelect    = { w = 244, h =  42, l = 0.286133, r = 0.524414, t = 0.317383, b = 0.358398 },
		FilterLine                  = { w =   5, h =  11, l = 0.270508, r = 0.275391, t = 0.468750, b = 0.479492 },
		RowHighlight                = { w = 116, h =  18, l = 0.547852, r = 0.661133, t = 0.252930, b = 0.270508 },
		RowSelect                   = { w = 116, h =  18, l = 0.807617, r = 0.920898, t = 0.209961, b = 0.227539 },
		SortArrow                   = { w =   9, h =   9, l = 0.987305, r = 0.996094, t = 0.025391, b = 0.034180 },
		SellTabLeft                 = { w =   9, h =  23, l = 0.987305, r = 0.996094, t = 0.000977, b = 0.023438 },
		SellTabMiddle               = { w =  95, h =  23, l = 0.000977, r = 0.093750, t = 0.967773, b = 0.990234 },
		SellTabRight                = { w =   9, h =  23, l = 0.270508, r = 0.279297, t = 0.428711, b = 0.451172 },
		IconFavorite                = { w =  40, h =  36, l = 0.940430, r = 0.979492, t = 0.047852, b = 0.083008 },
		IconFavoriteOff             = { w =  40, h =  36, l = 0.940430, r = 0.979492, t = 0.084961, b = 0.120117 },
		CoinGold                    = { w =  20, h =  20, l = 0.961914, r = 0.981445, t = 0.122070, b = 0.141602 },
		CoinSilver                  = { w =  20, h =  20, l = 0.931641, r = 0.951172, t = 0.143555, b = 0.163086 },
		CoinCopper                  = { w =  20, h =  20, l = 0.940430, r = 0.959961, t = 0.122070, b = 0.141602 },
		InputFieldLeft              = { w =   8, h =  33, l = 0.235352, r = 0.250977, t = 0.833008, b = 0.897461 },
		InputFieldMiddle            = { w = 178, h =  33, l = 0.286133, r = 0.633789, t = 0.143555, b = 0.208008 },
		InputFieldRight             = { w =   8, h =  33, l = 0.252930, r = 0.268555, t = 0.833008, b = 0.897461 },
		LoadingSpinner              = { w = 290, h = 290, l = 0.000977, r = 0.284180, t = 0.143555, b = 0.426758 },
	}),

	AuctionHouseBackgrounds = TextureAtlas("skin\\auctionhouse\\auctionhouse-backgrounds", 2048, 1024, 2048, 1024, {
		Index       = { w = 595, h = 413, l = 0.180664, r = 0.471191, t = 0.390625, b = 0.793945 },
		Categories  = { w = 138, h = 433, l = 0.845215, r = 0.912598, t = 0.390625, b = 0.813477 },
		SellLeft    = { w = 357, h = 437, l = 0.000488, r = 0.174805, t = 0.389648, b = 0.816406 },
		SellRight   = { w = 399, h = 418, l = 0.540527, r = 0.735352, t = 0.390625, b = 0.798828 },
		BuyHeader   = { w = 617, h =  81, l = 0.180664, r = 0.481934, t = 0.309570, b = 0.388672 },
		BuyMarket   = { w = 595, h = 277, l = 0.472168, r = 0.762695, t = 0.000977, b = 0.271484 },
		SummaryList = { w = 138, h = 433, l = 0.472168, r = 0.539551, t = 0.390625, b = 0.813477 },
		Auctions    = { w = 595, h = 314, l = 0.180664, r = 0.471191, t = 0.000977, b = 0.307617 },
	}),

	-- Retail's bank window (BankPanelEdgeShadowTemplate): the shadow the item
	-- area's edges cast inward. The corners and the horizontal band share one
	-- sheet (5782246), the vertical bands have their own (5779392); a band is
	-- uniform along its length and is stretched over it.
	BankShadows = TextureAtlas("skin\\bank\\bank-frame-shadows", 256, 256, 256, 256, {
		CornerBottomLeft  = { w =  46, h = 46, l = 0.003906, r = 0.183594, t = 0.683594, b = 0.863281 },
		CornerBottomRight = { w =  46, h = 46, l = 0.218750, r = 0.398438, t = 0.261719, b = 0.441406 },
		Bottom            = { w = 256, h = 17, l = 0.000000, r = 1.000000, t = 0.007813, b = 0.074219 },
	}),

	BankShadowsVertical = TextureAtlas("skin\\bank\\bank-frame-shadows-vert", 128, 256, 128, 256, {
		Right = { w = 17, h = 256, l = 0.015625, r = 0.148438, t = 0.000000, b = 1.000000 },
		Left  = { w = 17, h = 256, l = 0.164063, r = 0.296875, t = 0.000000, b = 1.000000 },
	}),

	TalentsAnimationParticles = TextureAtlas("skin\\talents\\talents-animations", 2048, 2048, 2048, 2048, {
		Particles = { w = 1308, h = 774, l = 0.000488, r = 0.639160, t = 0.379395, b = 0.757324 },
	})
}
