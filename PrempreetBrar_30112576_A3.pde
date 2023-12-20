/*
 Author: Prempreet Brar
 UCID: 30112576
 
 This artistic visualization aims to represent typing in space. Keyboard inputs
 are:
 
 1. Keyboard character that was pressed -> mapped to a shape on the canvas based
 on its keyboard position (with a slight offset from the center of the key to
 prevent overlap).
 2. Type of key pressed -> mapped to the colour of the shape. Yellow is for numbers,
 pink for consonants, blue for vowels, purple for puncutation, and green for miscellaneous
 symbols (like +, =, ~, etc.)
 3. Duration of keystroke -> mapped to the size of the shape. The longer the duration, the larger
 the shape representing the keypress.
 4. Shift -> mapped to the displayed shape itself. A square shape is displayed when shift is held,
 a circle is displayed when shift is not held.
 5. Spacebar -> connects all the current "stars" (shapes) on screen to form a constellation.
 6. Backspace or Delete -> Changes the background colour by pulsating it to be red. Disconnects a
 constellation if the letter formed part of a constellation.
 7. Speed at which you finished typing the word -> brightness of the constellation.
 
 Mouse inputs are:
 
 1. Cursor dragged on screen -> A shooting star that follows your cursor; it "finishes" when your
 cursor stops moving.
 2. Type of click (left or right) -> Left click displays an asteroid on the screen, right click
 displays a rocket.
 
 NOTE: I declare variables that will never be reassigned "final." While this may
 seem excessive, it's to ensure I do not make any errors.
 */

import java.util.HashSet;

int MAX_OFFSETY;
final int VERTICAL_MARGIN = 150;
final int VERTICAL_COMPRESS_FACTOR = 2;
final int VERTICAL_KEY_PADDING = 50;
final int VERTICAL_ADJUSTMENT_FOR_TWO_KEYS = 3;

final int HORIZONTAL_MARGIN = 200;
final int HORIZONTAL_COMPRESS_FACTOR = 2;
final int HORIZONTAL_KEY_PADDING = 100;

final int MIN_SHAPE_RADIUS = 50;
final float SHAPE_RADIUS_SCALING_FACTOR = 0.05;

final int SLOWEST_WORDS_PER_MINUTE = 20;
final float SLOWEST_SECONDS_PER_WORD = 60 / SLOWEST_WORDS_PER_MINUTE;
final float SLOWEST_SPEED_MS = SLOWEST_SECONDS_PER_WORD * 1000;

final int ARROW_SIZE = 10;

PImage asteroid;
PImage rocket;
ArrayList<PVector> asteroids = new ArrayList<>();
ArrayList<PVector> rockets = new ArrayList<>();

/* We hold each key's coordinate position, along with its max offset from that coordinate
 position. This is because if we had no offset, then the same key would just overlap itself
 multiple times, and the user would not be able to tell that the key was pressed more than once.
 The max offset tells us how much of a change in position is permissable from the key's original
 location.
 */
final HashMap<Character, PVector> keyPositions = new HashMap<>();
final HashMap<Character, Integer> keyHorizontalMaxOffsets = new HashMap<>();

/*
  All the classifications for the different characters, necessary for knowing what colour should be
 used for a keypress.
 */
HashSet<Character> numbers = new HashSet<>();
HashSet<Character> consonants = new HashSet<>();
HashSet<Character> vowels = new HashSet<>();
HashSet<Character> punctuation = new HashSet<>();
HashSet<Character> miscellaneous = new HashSet<>();

/*
  To simulate a shooting star, we simply remember the last _ mouse positions, and draw a line from the
 oldest position to the most recent position.
 */
final int TRAIL_LENGTH = 10;
final ArrayList<PVector> cursorTrail = new ArrayList<>();

/*
  Any time a key is pressed, we remember the key itself (so that we can tell if it was a backspace or space and
 deal with this special case accordingly), its position on the screen (this differs from the assigned key positions at
 the start because each key is given a random offset), its colour, shape, and time (which helps with determining the size
 of the shape on the screen).
 */
final ArrayList<Character> previouslyPressedKeys = new ArrayList<>();
final ArrayList<PVector> previouslyPressedKeysPositions = new ArrayList<>();
final ArrayList<Integer> previouslyPressedKeysColours = new ArrayList<>();
final ArrayList<String> previouslyPressedKeysShapes = new ArrayList<>();
final ArrayList<Integer> previouslyPressedKeysTime = new ArrayList<>();

/*
  constellationPoints holds the positions of all the letters in the user's "current" word
 that they are typing. Once they hit spacebar, the word is deemed to be "finished", put into constellations,
 and constellationPoints is then cleared to make way for a new word.
 
 The "speed" of a constellation is the time from the first letter press to when the user hits spacebar. The
 faster they hit spacebar, the quicker the speed at which the word was typed, and the BRIGHTER the constellation.
 */
ArrayList<PVector> constellationPoints = new ArrayList<>();
final ArrayList<ArrayList<PVector>> constellations = new ArrayList<>();
final ArrayList<Integer> constellationSpeeds = new ArrayList<>();

/*
  We need to know if a key is already currently pressed. This is because
 if a user is "holding" a key, we do not want multiple "stars" to show up on the screen.
 As mentioned above, holding a key should instead influence the radius or size of a star,
 NOT the number of stars drawn on the screen.
 */
HashMap<Character, Integer> currentlyPressedKeys = new HashMap<>();
boolean isShiftPressed = false;

int startTimeOfWord;
int penalty;

void setup() {
  /*
    The size was picked arbitarily; it has no real meaning. My laptop is
   13 inches by 13 inches, so I picked a size that would work on my screen
   (and all larger screens).
   */
  size(1280, 720);
  asteroid = loadImage("asteroid.png");
  rocket = loadImage("rocket.png");

  assignKeyPositions();
  setupCharacterClassifications();

  // background is black to resemble space
  background(0, 0, 0);
}

void assignKeyPositions() {
  /*
    We create an array of the relevant keys on the keyboard, splitting it up into
   rows. This allows us to iterate through each row of the keyboard and assign it
   a position on the screen. You'll notice that certain keys have multiple characters
   (such as 1 and !). This is because these characters share the same key on the keyboard.
   
   Consequently, we will map these characters to the same keyPosition on the screen,
   but with a slight offset so that they are not completely overlapping (so if someone
   presses 1 and !, you should still be able to see it).
   */
  final Object[][] keys = {
    {"`~", "1!", "2@", "3#", "4$", "5%", "6^", "7&", "8*", "9(", "0)", "-_", "=+", "PLACEHOLDER"},
    {TAB, 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', "[{", "]}", "\\|"},
    {"PLACEHOLDER", 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ";:", "\'\"", ENTER},
    {"PLACEHOLDER", 'z', 'x', 'c', 'v', 'b', 'n', 'm', ",<", ".>", "/?", "PLACEHOLDER"},
    {' '},
  };

  /*
    We don't want our rows to go right up to the edge of the screen. This is why we subtract
   a vertical padding from our height to get our "actual" height which we can use for our
   keyboard keys. We take that height and divide it by keys.length to get the number of rows
   in our 2D array. This is the height that each row can obtain.
   
   However, we notice that our row height is still too large. Therefore, we divide by 2
   so that the keyboard row doesn't seem too tall. The 2 is an arbitrary number.
   We could have easily picked something else.
   */
  final int useableScreenHeight = height - VERTICAL_MARGIN;
  final int stretchedRowHeight = useableScreenHeight / keys.length;
  final int rowHeight = stretchedRowHeight / VERTICAL_COMPRESS_FACTOR;

  final int remainingVerticalSpace = useableScreenHeight - rowHeight * keys.length;
  /*
    The spaces between is one less than the number of rows. For example, if you had
   4 rows, you would only have three spaces between those rows. Therefore, the remaining
   vertical space only needs to be apportioned to the number of rows - 1.
   */
  final int verticalSpaceBetweenRows = remainingVerticalSpace / (keys.length - 1);

  /*
   We're mapping each keyboard press to its position on the screen. However, if we press the same key multiple
   times, we don't want the presses to overlap. Therefore, we must offset each press from the key's position by
   a certain amount. However, if we offset by too much, then the dot on the screen will move into the "territory" of
   another key. Therefore, we have a limit as to how much we can offset.
   
   Since each dot is originally going to be in the vertical middle of its row, the offset is at most half the row height.
   This is because the dot could either be placed at the top of the row (moving up by half), or at the bottom (moving down
   by half).
   */
  MAX_OFFSETY = rowHeight / 2;

  final int useableScreenWidth = width - HORIZONTAL_MARGIN;

  for (int r = 0; r < keys.length - 1; r++) {
    final Object[] keyRow = keys[r];

    /*
      When figuring out the vertical position of a key, we have to "skip" all the rows before it,
     and then add rowHeight / 2 because we want it to be in the middle of its row.
     
     Finally, the vertical key padding is just an arbitrary value added to shift all the keys down
     the screen slightly. This is because even though we subtracted the VERTICAL_MARGIN to get the
     useableScreenHeight, that useableScreenHeight will still start at y = 0 for our key position
     unless we add padding to it.
     
     More succinctly, we subtract VERTICAL_MARGIN so that our keys don't touch the bottom edge. However,
     we still don't want our keys to touch the top edge either, so we add VERTICAL_KEY_PADDING.
     
     */
    final int verticalSpaceSkipped = r * (verticalSpaceBetweenRows + rowHeight);
    final int y = verticalSpaceSkipped + rowHeight / 2 + VERTICAL_KEY_PADDING;

    /*
      The width of each key depends on how many keys there are in the row. We then
     divide this number by 2 (the horizontal compress factor) so that the keys don't look
     too wide (as that would look quite weird on the screen).
     */
    final int keyWidth = (useableScreenWidth / keyRow.length) / HORIZONTAL_COMPRESS_FACTOR;
    final int remainingHorizontalSpace = useableScreenWidth - keyWidth * keyRow.length;
    final int horizontalSpaceBetweenKeys = remainingHorizontalSpace / (keyRow.length - 1);

    for (int c = 0; c < keyRow.length; c++) {
      final int horizontalSpaceSkipped = c * (keyWidth + horizontalSpaceBetweenKeys);
      // put the key in the horizontal middle of its column
      final int x = horizontalSpaceSkipped + keyWidth / 2 + HORIZONTAL_KEY_PADDING;

      /*
        In our array, we used a string for keys with multiple characters (double quotes). This
       lets us "fit" two keys in the same position, with the shifted character slightly higher
       (just like how it appears on a regular keyboard) and the regular character slightly lower.
       */
      if (keyRow[c] instanceof String) {
        final int yOfShiftedCharacter = y - rowHeight / VERTICAL_ADJUSTMENT_FOR_TWO_KEYS;
        final int yOfRegularCharacter = y + rowHeight / VERTICAL_ADJUSTMENT_FOR_TWO_KEYS;

        /*
          We'll create two keys. Since each key is at the horizontal center of its "spot"
         on the screen, our maxOffset we can do horizontally is half of the key's width.
         */
        keyPositions.put(((String)keyRow[c]).charAt(0), new PVector(x, yOfRegularCharacter));
        keyPositions.put(((String)keyRow[c]).charAt(1), new PVector(x, yOfShiftedCharacter));
        keyHorizontalMaxOffsets.put(((String)keyRow[c]).charAt(0), keyWidth / 2);
        keyHorizontalMaxOffsets.put(((String)keyRow[c]).charAt(1), keyWidth / 2);
      } else {
        keyPositions.put((char)keyRow[c], new PVector(x, y));
        keyHorizontalMaxOffsets.put((char)keyRow[c], keyWidth / 2);
      }
    }
  }

  int verticalSpaceSkippedToGetToLastRow = (keys.length - 1) * (verticalSpaceBetweenRows + rowHeight);
  int yLast = verticalSpaceSkippedToGetToLastRow + rowHeight / 2 + VERTICAL_KEY_PADDING;
  /*
    The last row contains only a spacebar. Therefore, we should put it in the middle of the screen. It can
   also take up a good portion of the screen.
   */
  int xLast = useableScreenWidth / 2 + HORIZONTAL_KEY_PADDING;
  int lastKeyWidth = useableScreenWidth / 2;
  keyPositions.put(' ', new PVector(xLast, yLast));
  keyHorizontalMaxOffsets.put(' ', lastKeyWidth / 2);
}

void setupCharacterClassifications() {
  // Initialize sets with corresponding characters
  setupCharacterClassification(numbers, "1234567890");
  setupCharacterClassification(consonants, "bcdfghjklmnpqrstvwxyz");
  setupCharacterClassification(vowels, "aeiou");
  setupCharacterClassification(punctuation, "!&();:\'\",./?");
  setupCharacterClassification(miscellaneous, "~`@#$%^*_-+={[}]|\\<>");
}

void setupCharacterClassification(HashSet<Character> set, String characters) {
  for (char c : characters.toCharArray()) {
    set.add(c);
  }
}

void drawCursorTrail() {
  stroke(255, 100);
  strokeWeight(2);
  cursorTrail.add(new PVector(mouseX, mouseY));

  /*
    Remove the oldest mouse position to simulate the shooting star "dying".
   */
  if (cursorTrail.size() > TRAIL_LENGTH) {
    cursorTrail.remove(0);
  }

  /*
    Start at i = 1, because we draw a line from the previous position to the current position.
   At i = 0, there is no previous position for us to use.
   */
  for (int i = 1; i < cursorTrail.size(); i++) {
    line(cursorTrail.get(i - 1).x, cursorTrail.get(i - 1).y, cursorTrail.get(i).x, cursorTrail.get(i).y);
  }
}

void drawAsteroids() {
  for (PVector asteroidPos : asteroids) {
    image(asteroid, asteroidPos.x - asteroid.width / 2, asteroidPos.y - asteroid.height / 2);
  }
}

void drawRockets() {
  for (PVector rocketPos : rockets) {
    image(rocket, rocketPos.x - rocket.width / 2, rocketPos.y - rocket.height / 2);
  }
}

void drawpreviouslyPressedKeys() {
  /*
    If the user is typing very fast, a keystroke may not take much time. In that situation, we still want to show the keypress, so we force the circle
   to be a minimum size.
   
   We set strokeWeight to 0.1, so that the regular "stars" (shapes) do not have a thick outline.
   */
  strokeWeight(0.1);

  for (int i = 0; i < previouslyPressedKeysPositions.size(); i++) {
    fill(previouslyPressedKeysColours.get(i));
    if (previouslyPressedKeysShapes.get(i) == "circle") {
      circle(previouslyPressedKeysPositions.get(i).x, previouslyPressedKeysPositions.get(i).y, min(previouslyPressedKeysTime.get(i) * SHAPE_RADIUS_SCALING_FACTOR, MIN_SHAPE_RADIUS));
    } else if (previouslyPressedKeysShapes.get(i) == "square") {
      square(previouslyPressedKeysPositions.get(i).x, previouslyPressedKeysPositions.get(i).y, min(previouslyPressedKeysTime.get(i) * SHAPE_RADIUS_SCALING_FACTOR, MIN_SHAPE_RADIUS));
    }
  }
}

void drawArrowhead(PVector start, PVector end) {
  /*
    Calculate the angle between the two "stars" (shapes) in radians.
   This is the angle the arrowhead should be facing.
   
   The arrowhead should be at the end point (in fact, the end is what's
   mostly relevant here. We only pass in the start, aka the coordinate of the
   previous star, so that we know what angle the arrowhead should be).
   
   arrowX1 is calculating how much to move horizontally from the endpoint.
   arrowY1 is calculating how much to move horizontally from the endpoint.
   Together, they will form one "branch" of the arrow.
   
   arrowX2 and arrowY2 are the same, just in the opposite direction. They form the
   other "branch" of the arrow. Therefore, when we draw both branch 1 and 2, we form a
   "V" coming out from the endpoint, making it look like we have an arrow.
   
   In reality, we don't have an arrow; it's just two lines connecting together to form a "v".
   
   We do PI / 6 because 30 degrees in radians is PI / 6. We want our "branches" to be at a 30
   degree angle. If we wanted a narrower or wider arrowhead, we would adjust those accordingly.
   */
  float angle = atan2(end.y - start.y, end.x - start.x);
  float arrowX1 = end.x - ARROW_SIZE * cos(angle - PI / 6);
  float arrowY1 = end.y - ARROW_SIZE * sin(angle - PI / 6);
  float arrowX2 = end.x - ARROW_SIZE * cos(angle + PI / 6);
  float arrowY2 = end.y - ARROW_SIZE * sin(angle + PI / 6);

  line(end.x, end.y, arrowX1, arrowY1);
  line(end.x, end.y, arrowX2, arrowY2);
}

void drawConstellation(ArrayList<PVector> constellation, float speed) {
  /*
   Speed determines the brightness of the constellation. If the user is slower than the
   slowest speed, we'll just default them to the slowest_speed. We need the slowest speed
   because we need SOME "barrier" at which the constellation is dimmest.
   */
  speed = min(SLOWEST_SPEED_MS, speed);
  /*
   The lower bound of speed is the slowest speed, the upper bound is 0 (if someone typed
   their word instantaneously), and we'll map this to a brightness between 50 and 255.
   */
  float alpha = map(speed, SLOWEST_SPEED_MS, 0, 50, 255);
  stroke(255, alpha);

  for (int i = 1; i < constellation.size(); i++) {
    line(constellation.get(i - 1).x, constellation.get(i - 1).y, constellation.get(i).x, constellation.get(i).y);
    drawArrowhead(constellation.get(i - 1), constellation.get(i));
  }
}

void drawConstellations() {
  strokeWeight(1);
  for (int i = 0; i < constellations.size(); i++) {
    drawConstellation(constellations.get(i), constellationSpeeds.get(i));
  }
}

void draw() {
  background(0, 0, 0);

  drawCursorTrail();
  drawAsteroids();
  drawRockets();
  drawpreviouslyPressedKeys();
  drawConstellations();
}

void keyPressed() {
  key = Character.toLowerCase(key);
  /*
    Record the time at which the key was pressed so that we can eventually determine
   the length of the keystroke. Make sure its actually a key we care about though.
   For example, don't record the "escape" key.
   */
  if (!currentlyPressedKeys.containsKey(key) && keyPositions.containsKey(key)) {
    currentlyPressedKeys.put(key, millis());
  }

  if (key == CODED) {
    if (keyCode == SHIFT) {
      isShiftPressed = true;
    }
  }

  /*
    If the user clicked backspace, then "flash" the screen red. Ensure that there is
   actually a key that can be deleted though.
   */
  if (key ==  BACKSPACE && previouslyPressedKeysPositions.size() > 0) {
    background(255, 0, 0);
  }
}

void handleWhitespaceBackspace() {
  /*
      Check if there is a previous letter to go back to. If the previous letter is a space,
   then we're still not in a constellation, so we don't need to handle anything. However,
   if the previous letter is NOT a space, that means it is an actual character. This means
   we are now on an "actual" word that we previously typed, as we just removed the space
   that completed it. Therefore, the constellation reperesenting that word is now "open" and
   is our current constellation.
   
   However, we know that the brightness of a constellation depends on how quickly it is
   completed. Now, we're editing a constellation. How would we determine its brightness?
   Well, we simply mark the startTime as the currentTime, and record the original time
   taken as a penalty. This way, once the user has finished editing the word, the new time
   taken for completion is the orignal completion time + time taken for editing.
   */
  if (previouslyPressedKeys.size() > 0) {
    char mostRecentKey = previouslyPressedKeys.get(previouslyPressedKeys.size() - 1);
    if (mostRecentKey != ' ' && mostRecentKey != TAB && mostRecentKey != ENTER) {
      constellationPoints = constellations.remove(constellations.size() - 1);
      startTimeOfWord = millis();
      penalty = constellationSpeeds.remove(constellationSpeeds.size() - 1);
    }
  }
}

void handleBackspace() {
  /*
    If we backspace, we need to remove the "star" (shape) from the screen regardless
   of what type it is. However, if it is a whitespace, then that means we need to check
   what constellation we are now in (as a whitespace is not part of any constellation). If
   it is a non white space, then we know that the letter was removed from our current constellation.
   */
  char deletedKey = previouslyPressedKeys.remove(previouslyPressedKeys.size() - 1);
  previouslyPressedKeysPositions.remove(previouslyPressedKeysPositions.size() - 1);
  previouslyPressedKeysColours.remove(previouslyPressedKeysColours.size() - 1);
  previouslyPressedKeysTime.remove(previouslyPressedKeysTime.size() - 1);
  previouslyPressedKeysShapes.remove(previouslyPressedKeysShapes.size() - 1);

  if (deletedKey == ' ' || deletedKey == TAB || deletedKey == ENTER) {
    handleWhitespaceBackspace();
  } else {
    constellationPoints.remove(constellationPoints.size() - 1);
  }
}

int classifyKey(char key) {
  if (numbers.contains(key)) {
    return color(255, 255, 0);
  } else if (consonants.contains(key)) {
    return color(255, 0, 255);
  } else if (vowels.contains(key)) {
    return color(0, 191, 255);
  } else if (punctuation.contains(key)) {
    return color(138, 43, 226);
  } else if (miscellaneous.contains(key)) {
    return color(0, 255, 127);
  } else {
    return color(255);
  }
}

void handleRegularKeyRelease(PVector keyPosition, float randomOffsetX, float randomOffsetY) {
  /*
    If the user just typed a regular character, the clock is now running for this constellation
   (aka word).
   */
  if (constellationPoints.isEmpty()) {
    startTimeOfWord = millis();
    penalty = 0;
  }
  constellationPoints.add(new PVector(keyPosition.x + randomOffsetX, keyPosition.y + randomOffsetY));
}

void handleWhitespaceKeyRelease() {
  /*
    If the user didn't just press spacebar without typing anything (ie. they
   actually typed letters), then go ahead and add the constellation.
   */
  if (constellationPoints.size() > 0) {
    constellations.add(new ArrayList<>(constellationPoints));
    constellationPoints.clear();
    constellationSpeeds.add(millis() - startTimeOfWord + penalty);
  }
}

void handleKeyRelease() {
  /*
     Compute a random position for the released key, classify its colour. Then, handle whitespace
   releases versus regular released fiferently.
   */
  previouslyPressedKeys.add(key);
  PVector keyPosition = keyPositions.get(key);
  float randomOffsetX = random(-keyHorizontalMaxOffsets.get(key), keyHorizontalMaxOffsets.get(key));
  float randomOffsetY = random(-MAX_OFFSETY, MAX_OFFSETY);

  int fillColor = classifyKey(key);
  previouslyPressedKeysPositions.add(new PVector(keyPosition.x + randomOffsetX, keyPosition.y + randomOffsetY));
  previouslyPressedKeysColours.add(fillColor);

  if (key == ' ' || key == TAB || key == ENTER) {
    handleWhitespaceKeyRelease();
  } else {
    handleRegularKeyRelease(keyPosition, randomOffsetX, randomOffsetY);
  }

  if (isShiftPressed) {
    previouslyPressedKeysShapes.add("square");
  } else {
    previouslyPressedKeysShapes.add("circle");
  }

  int timeOfPress = currentlyPressedKeys.remove(key);
  previouslyPressedKeysTime.add(millis() - timeOfPress);
}

void keyReleased() {
  if (key == CODED) {
    if (keyCode == SHIFT) {
      isShiftPressed = false;
      return;
    }
  }

  if (key ==  BACKSPACE && previouslyPressedKeysPositions.size() > 0) {
    /* If the user lets go of backspace, reset the screen to black. We don't want
     it to permanently be red.
     */
    background(0);
    handleBackspace();
  }

  key = Character.toLowerCase(key);
  if (currentlyPressedKeys.containsKey(key) && keyPositions.containsKey(key)) {
    handleKeyRelease();
  }
}

void mousePressed() {
  if (mouseButton == LEFT) {
    asteroids.add(new PVector(mouseX, mouseY));
  } else if (mouseButton == RIGHT) {
    rockets.add(new PVector(mouseX, mouseY));
  }
}
