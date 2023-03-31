extends Node

@export var width:int
@export var height:int
@export var patternSize:int
@export var maximumRecursionDepth:int

var patterns:Array[Pattern] # list of patterns
var patternWeights:Array[int] # elements are pairwise with 'patterns'; represents weight of a given pattern in a sample (i.e. number of occurances)
var totalWeight:int # the sum of the elements of 'patternWeights'; calculated once when sample array is read then never changed

var directionList:Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1)] # a list of all the valid direction offsets to compare one pattern to another; filled initially and never changed
# Array[Array[Array[int]]] x/y grid and for each cell a list that is a set of indicies
var currentOptions:Array # The current options possible for every grid square, actively changing while the algorithm runs, holds indicies into 'patterns'

# Array[Array[int]] x/y grid and for each cell its entropy
var currentEntropy:Array

var compatible:Array

var propagateStack:Array # list of [location:Vector2i, patternIndex:int] pairings who have been removed and whose information needs to be propagated to their neighbors

var f_time = {}
var f_count = {}
@onready var c_time = Time.get_ticks_usec()
var c_f = null
var f_enabled = false
var f_verbose = false
func f_next():
	if not f_enabled:
		return
		
	var n_time = Time.get_ticks_usec()
	var d_time = n_time - c_time
	if (c_f != null):
		if c_f not in f_time:
			f_time[c_f] = 0.0
			f_count[c_f] = 0
		f_time[c_f] += d_time
		f_count[c_f] += 1
		
		if (f_verbose):
			print ("function ", c_f, " latest:", d_time, " total=", f_time[c_f], " count=", f_count[c_f], " per=", float(f_time[c_f])/float(f_count[c_f]))
	c_f = get_stack()[1]["function"]
	c_time = Time.get_ticks_usec()
	
func f_print_all():
	print("***ALL***")
	for c_f in f_time.keys():
		print ("function ", c_f, " total=", f_time[c_f], " count=", f_count[c_f], " per=", float(f_time[c_f])/float(f_count[c_f]))
	

class Pattern:
	# all patterns are square, this is the side length of the square
	var size:int
	# double subscripted array of length size x size
	var data
	var wfc
	
	func _init(_size:int, _data, _wfc):
		size = _size
		data = _data
		wfc = _wfc
		
	func output():
		var output = ""
		for x in len(data):
			for y in len(data[x]):
				output += str(data[x][y])
			output += "\n"
		return output
	
	# returns true when this pattern and 'other' can be laid on top of each other when offseting 'other' by 'direction'
	func cleanlyMeshesWith(other:Pattern, direction:Vector2i):
		wfc.f_next()
		# early exit for non-overlapping patterns
		if \
		# if the other pattern is further in the +x than ours is long in the +x
		direction.x > 0 && direction.x > size || \
		# if the other pattern is further in the +y than ours is long in the +y
		direction.y > 0 && direction.y > size || \
		# if the other pattern is further in the -x than it is long
		direction.x < 0 && abs(direction.x) > other.size || \
		# if the other pattern is further in the -y than it is long
		direction.y < 0 && abs(direction.y) > other.size:
			return true
		
		# only loop over tiles that overlap
		# set start and end coords in the source pattern
		var startCoord:Vector2i;
		var endCoord:Vector2i;
		
		if direction.x > 0:
			startCoord.x = direction.x
			endCoord.x = size
		else:
			startCoord.x = 0
			endCoord.x = size - abs(direction.x)
		
		if direction.y > 0:
			startCoord.y = direction.y
			endCoord.y = size
		else:
			startCoord.y = 0;
			endCoord.y = size - abs(direction.y)
			
		for x in range(startCoord.x, endCoord.x):
			for y in range(startCoord.y, endCoord.y):
				if data[x][y] != other.data[x-direction.x][y-direction.y]:
					return false
		return true
			
	func matchesExactly(other:Pattern):
		return matchesExactly_rawData(other.data)
	
	func matchesExactly_rawData(other):
		for x in range(data.size()):
			for y in range(data[x].size()):
				if data[x][y] != other[x][y]:
					return false
		return true

func print_patterns():
	for pat in len(patterns):
		print("pattern ", pat, "=>\n", patterns[pat].output())
		

# modifies 'patterns', 'patternWeights'
# sampleArray: Array[Array[int]] x/y grid and for each cell is an int identifying what type that cell is
func parseSampleForPatterns(sampleArray:Array, patternSize:int):
	f_next()
	patterns = []
	patternWeights = []
	# for each row
	for x in range(sampleArray.size() - patternSize + 1):
		# for each column
		for y in range(sampleArray[0].size() - patternSize + 1):
			# pull 'patternSize' number of rows starting from (x,y)
			var pattern = []
			for s in range(patternSize):
				pattern.append(sampleArray[x+s].slice(y, y + patternSize))
			
			# add to the pattern list if this is new
			# otherwise increase its weight
			var matchFound:bool = false
			for p in range(patterns.size()):
				if patterns[p].matchesExactly_rawData(pattern):
					matchFound = true
					patternWeights[p] += 1
					break
			if not matchFound:
				patterns.append(Pattern.new(patternSize, pattern, self))
				patternWeights.append(1)
				
	totalWeight = 0
	for i in patternWeights:
		totalWeight += i
		
	print_patterns()

func getEntropy(x:int, y:int) -> float:
	f_next()
	if currentOptions[x][y].size() == 1:
		return 0
	
	var entropy:float = 0
	
	for optionIndex in currentOptions[x][y]:
		var prob = float(patternWeights[optionIndex]) / totalWeight
		entropy += prob * log(prob) / log(2)
	
	return -entropy

func isEveryCellDecided():
	f_next()
	for x in range(width):
		for y in range(height):
			if currentOptions.size() > 1:
				return false
	return true

# returns Vector2i of coords of entry in grid with least entropy
func getLeastNonzeroEntropy() -> Vector2i:
	f_next()
	var least:float = INF
	var coordWithLeast:Vector2i = Vector2i(-1, -1)
	for x in range(width):
		for y in range(height):
			if currentEntropy[x][y] < least && currentEntropy[x][y] > 0:
				least = currentEntropy[x][y]
				coordWithLeast = Vector2i(x, y)
	return coordWithLeast

func getWeightedRandomCellOption(pos:Vector2i) -> int:
	f_next()
	var totalCurrentWeight:int = 0
	for pattern in currentOptions[pos.x][pos.y]:
		totalCurrentWeight += patternWeights[pattern]
		
	var rand:int = randi_range(0, totalCurrentWeight - 1)
	
	var current:int = 0
	var currentWeight:int = 0
	while current < currentOptions[pos.x][pos.y].size():
		if rand <= currentWeight:
			return currentOptions[pos.x][pos.y][current]
		currentWeight += patternWeights[currentOptions[pos.x][pos.y][current]]
		current += 1
	
	return currentOptions[pos.x][pos.y][-1]

var meshes = {}
func cleanMeshWithMemoDict(parentOpt, opt, dir):
	f_next()
	if parentOpt not in meshes:
		meshes[parentOpt] = {}
	
	if opt not in meshes[parentOpt]:
		meshes[parentOpt][opt] = {}
		
	if dir not in meshes[parentOpt][opt]:
		meshes[parentOpt][opt][dir] = patterns[parentOpt].cleanlyMeshesWith(patterns[opt], indexToDirection(dir))
		
	return meshes[parentOpt][opt][dir]
	
#var meshList = []
# Array[Array[Array]]]
var meshList : Array
func cleanMeshWithMemoList(parentOpt, opt, dir):
	f_next()
	return meshList[parentOpt][opt][dir]
	
func cleanMeshWithMemoListConstruct():
	f_next()
	for dir in range(len(directionList)):
		var direction:Array = []
		for i in range(len(patterns)):
			var row:Array = []
			for j in range(len(patterns)):
					if patterns[i].cleanlyMeshesWith(patterns[j], directionList[dir]):
						row.append(j)
					if (i == 16 and j == 28):
						print("mesh? ", row[-1], " pi=", i, " pj=", j, " dir=", directionList[dir])
			direction.append(row)
		meshList.append(direction)
	
# returns bool; true if the propagate was successful, false if we reached a contradiction (a cell is left with no options)
# deals with all the elements on the propagate stack, perhaps increasing the number of elements in the process, but always reducing it to 0
func propagate():
	f_next()
	while propagateStack.size() > 0:
#		print("dealing with " + str(propagateStack[-1]))
		for d in range(directionList.size()):
			var neighborPos:Vector2i = propagateStack[-1][0] + directionList[d]
			
			if neighborPos.x < 0 || neighborPos.y < 0 || neighborPos.x >= width || neighborPos.y >= height:
				continue
			
			for p in meshList[d][propagateStack[-1][1]]:
#				print("compatible[neighborPos.x][neighborPos.y][p][d]=", compatible[neighborPos.x][neighborPos.y][p][d])
				compatible[neighborPos.x][neighborPos.y][p][d] -= 1
				if compatible[neighborPos.x][neighborPos.y][p][d] == 0:
#					print("banned here!")
					ban(neighborPos, p)
		propagateStack.pop_back()

func indexToDirection(i):
	return directionList[i]

func ban(pos:Vector2i, patternIndex:int):
#	print("banning " + str(patternIndex) + " at " + str(pos))
	if (currentOptions[pos.x][pos.y].size()==1):
		print("could banning the last one! currentOptions[", pos.x, "][", pos.y, "] patternIndex=", patternIndex, " currentOptions[pos.x][pos.y]=", currentOptions[pos.x][pos.y])
	currentOptions[pos.x][pos.y].erase(patternIndex)
	if (currentOptions[pos.x][pos.y].size()==0):
		print("actually")
	currentEntropy[pos.x][pos.y] = getEntropy(pos.x, pos.y)
	
	for d in range(directionList.size()):
		compatible[pos.x][pos.y][patternIndex][d] = 0
	
	propagateStack.append([pos, patternIndex])

func collapse(pos:Vector2i):
	f_next()
	var collapsedValue:int = getWeightedRandomCellOption(pos)
	
#	print("collapsing " + str(pos) + " to " + str(collapsedValue))
	
	for i in range(patterns.size()):
		if i != collapsedValue:
			ban(pos, i)

func initializeGrid():
	f_next()
	# fill 'possibleOptions' grid with all possible options, i.e. [0, 1, 2, ..., patterns.size()] for each cell
	currentOptions = []
	for x in range(width):
		currentOptions.append([])
		for y in range(height):
			currentOptions[-1].append([])
			for i in range(patterns.size()):
				currentOptions[-1][-1].append(i)
				
	# fill 'currentEntropy' array
	currentEntropy = []
	for x in range(width):
		currentEntropy.append([])
		for y in range(height):
			currentEntropy[-1].append(getEntropy(x, y))

# modifies 'currentOptions'
# modifies 'currentEntropy'
func generateTerrainGrid(width:int, height:int):
	f_next()
	initializeGrid()
	seed(999899)
	
	while not isEveryCellDecided():
		var pos:Vector2i = getLeastNonzeroEntropy()
		if pos.x == -1: # getLeastNonzeroEntropy returns (-1, -1) if all cells have entropy 0
			break
		collapse(pos)
		propagate()

# we assume sizes are correct
func restoreFromBackup(backupOptions:Array, backupEntropies:Array):
	currentOptions = backupOptions.duplicate(true)
	currentEntropy = backupEntropies.duplicate(true)
	
func makeBackupOfOptionsAndEntropies():
	return [currentOptions.duplicate(true), currentEntropy.duplicate(true)]

func _input(event):
#	if event.is_action_pressed("Jump"):
#		do()
	pass

func initializeCompatible():
	compatible = []
	for x in range(width):
		compatible.append([])
		for y in range(height):
			compatible[-1].append([])
			for p in range(patterns.size()):
				compatible[-1][-1].append([])
				for d in range(directionList.size()):
					compatible[-1][-1][-1].append(meshList[(d + 2) % 4][p].size())
					print("x=", x, " y=", y, " p=", p, " d=", d, " Adding, compatible=> p=", p, " compatible[-1][-1][-1]=", compatible[-1][-1][-1], "\n", patterns[p].output())
#					for meshed in meshList[(d + 2) % 4][p]:
#						print("meshed, ", meshed, " \n", patterns[meshed].output())
					
@onready var tile_map = $"../TileMap"
func do():
	var imageConverter = get_tree().get_root().get_child(0).find_child("ImageConverter")
	var sampleImage = imageConverter.to_array("res://sprite-0002.png")
	parseSampleForPatterns(sampleImage, patternSize)
	cleanMeshWithMemoListConstruct()
	initializeCompatible()
	generateTerrainGrid(width, height)
	
	var currentOptionsClone = currentOptions.duplicate(true)
	for x in range(width):
		for y in range(height):
			currentOptionsClone[x][y] = patterns[currentOptions[x][y][0]].data[0][0]
	
	var mapInfo = get_tree().get_root().get_child(0).find_child("CanvasLayer").find_child("MapInfo")
	mapInfo.load_all(currentOptionsClone, currentOptionsClone)
	tile_map.display(currentOptions, patterns)
	
# Called when the node enters the scene tree for the first time.
func _ready():
	do()
#	f_print_all()
	pass
