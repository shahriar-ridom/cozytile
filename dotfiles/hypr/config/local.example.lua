-- Machine-specific settings. Copy to config/local.lua (git-ignored); it is loaded last.
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@100", position = "auto", scale = 1 })
hl.env("LIBVA_DRIVER_NAME", "radeonsi")   -- AMD VAAPI
