-- Boots client subsystems that have no natural first caller of their own --
-- previously these were required as a side effect of CameraSession loading,
-- which meant an unrelated failure in either of them (e.g. the objective
-- remote never replicating) could take the camera down with it. Now they
-- boot independently, at game start, regardless of whether the player has
-- ever touched a camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Modules.Flash.FlashRenderers)
require(ReplicatedStorage.Modules.Objective.ObjectiveVisualsController)
