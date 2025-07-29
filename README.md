# HoverTracker

Super light-weight and simple FFXI add-on for tracking Hover Shot stacks and validating the movement requirement for gaining stacks.

![wrong](images/nomove.png)
![right](images/goodmove.png)

Usage:
```lua
//lua load hovertracker
```

Automatic visual display when Hover Shot is active a enemy has been claimed.

Commands:
```lua
-- Enable display (display enabled by default) 
//ht show

-- Hide display
//ht hide

-- Manually reset stack count
//ht reset

-- Enable log output for additional information on shots and distance moved
//ht debug
```