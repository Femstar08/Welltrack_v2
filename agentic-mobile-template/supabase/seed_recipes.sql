-- WellTrack Recipe Seed Data
-- 16 recipes generated from food photos

INSERT INTO wt_recipes (
  title,
  description,
  cuisine_type,
  meal_type,
  prep_time_min,
  cook_time_min,
  servings,
  serving_size_description,
  ingredients,
  instructions,
  calories_per_serving,
  protein_per_serving,
  carbs_per_serving,
  fat_per_serving,
  fibre_per_serving,
  tags,
  is_public,
  source_type
) VALUES

-- 1. Nigerian Breakfast Plate
(
  'Nigerian Breakfast Plate',
  'A hearty West African breakfast combining puff puff, grilled mackerel, stewed offal, boiled cabbage, baked beans, and fried yam. High protein, filling, and full of flavour.',
  'Nigerian',
  'breakfast',
  20, 35, 1,
  '1 full plate (~550g)',
  '[{"item":"mackerel fillet","quantity":120,"unit":"g"},{"item":"puff puff (fried dough balls)","quantity":90,"unit":"g"},{"item":"stewed beef offal","quantity":80,"unit":"g"},{"item":"white cabbage","quantity":60,"unit":"g"},{"item":"baked beans in tomato sauce","quantity":100,"unit":"g"},{"item":"yam","quantity":100,"unit":"g"},{"item":"vegetable oil for frying","quantity":30,"unit":"ml"},{"item":"salt","quantity":1,"unit":"tsp"},{"item":"pepper","quantity":0.5,"unit":"tsp"}]'::jsonb,
  '[{"step":1,"instruction":"Season mackerel fillet with salt, pepper, and a pinch of curry powder. Grill on medium heat for 6-8 minutes each side until cooked through and lightly charred."},{"step":2,"instruction":"Peel and slice yam into rounds 1cm thick. Deep fry in vegetable oil at 170C for 8-10 minutes until golden and cooked through. Drain on kitchen paper."},{"step":3,"instruction":"Boil cabbage wedge in salted water for 4-5 minutes until just tender. Drain and set aside."},{"step":4,"instruction":"Heat baked beans in a small saucepan over medium heat for 3-4 minutes, stirring occasionally."},{"step":5,"instruction":"Warm the stewed offal in a pan with a splash of water and any residual sauce for 3-4 minutes."},{"step":6,"instruction":"Arrange all components on a plate: mackerel, puff puff, offal, cabbage, beans, and fried yam. Serve immediately."}]'::jsonb,
  720, 38, 62, 32, 8,
  ARRAY['nigerian','breakfast','high-protein','fish','traditional'],
  true, 'photo'
),

-- 2. Mushroom & Vegetable Omelette with Toast
(
  'Mushroom & Vegetable Omelette',
  'A fluffy folded omelette packed with mushrooms, red onion, mixed peppers, and spring onion. Served with a slice of toasted bread. Quick, protein-rich, and satisfying.',
  'British',
  'breakfast',
  8, 8, 1,
  '1 omelette + 1 slice toast (~280g)',
  '[{"item":"eggs","quantity":3,"unit":"large"},{"item":"chestnut mushrooms, sliced","quantity":80,"unit":"g"},{"item":"red onion, diced","quantity":30,"unit":"g"},{"item":"mixed peppers, diced","quantity":40,"unit":"g"},{"item":"spring onion, sliced","quantity":15,"unit":"g"},{"item":"butter","quantity":10,"unit":"g"},{"item":"salt and black pepper","quantity":1,"unit":"pinch"},{"item":"wholegrain bread","quantity":1,"unit":"slice"}]'::jsonb,
  '[{"step":1,"instruction":"Heat butter in a non-stick pan over medium heat. Add red onion and peppers and saute for 2 minutes until softened."},{"step":2,"instruction":"Add mushrooms and cook for 3 minutes until golden and moisture has evaporated. Add spring onions and stir briefly. Transfer vegetables to a bowl."},{"step":3,"instruction":"Crack eggs into a bowl, season with salt and pepper, and whisk well."},{"step":4,"instruction":"Return pan to medium heat with a small knob of butter. Pour in eggs and let them set at the edges (30 seconds), then use a spatula to gently push cooked egg from the edges toward the centre."},{"step":5,"instruction":"When egg is mostly set but still slightly glossy on top, scatter the cooked vegetables over one half. Fold the omelette over and slide onto a plate."},{"step":6,"instruction":"Toast bread and serve alongside the omelette."}]'::jsonb,
  380, 24, 22, 20, 3,
  ARRAY['eggs','breakfast','high-protein','quick','vegetarian'],
  true, 'photo'
),

-- 3. Nigerian Power Breakfast
(
  'Nigerian Power Breakfast',
  'A performance-focused Nigerian breakfast plate: grilled white fish, soft scrambled eggs, fried plantain, crispy akara (bean cakes), and herb-roasted tomatoes. High protein, complex carbs, sustained energy.',
  'Nigerian',
  'breakfast',
  15, 25, 1,
  '1 full plate (~500g)',
  '[{"item":"white fish fillet (tilapia or croaker)","quantity":150,"unit":"g"},{"item":"eggs","quantity":2,"unit":"large"},{"item":"ripe plantain","quantity":1,"unit":"medium"},{"item":"akara (bean cakes)","quantity":3,"unit":"pieces"},{"item":"plum tomatoes","quantity":2,"unit":"halved"},{"item":"fresh thyme","quantity":1,"unit":"tsp"},{"item":"vegetable oil","quantity":20,"unit":"ml"},{"item":"butter","quantity":10,"unit":"g"},{"item":"salt and pepper","quantity":1,"unit":"pinch"}]'::jsonb,
  '[{"step":1,"instruction":"Season fish fillet with salt, pepper, and a pinch of paprika. Pan-grill or grill on medium-high heat for 4-5 minutes per side until cooked through and lightly golden."},{"step":2,"instruction":"Peel plantain and slice diagonally into 1cm rounds. Shallow fry in oil for 2-3 minutes each side until golden and caramelised. Drain on paper towel."},{"step":3,"instruction":"Place tomato halves cut-side up on a baking tray, drizzle with oil, scatter with thyme, salt and pepper. Roast at 200C for 15 minutes until softened and slightly charred."},{"step":4,"instruction":"Whisk eggs with a pinch of salt. Melt butter in a pan over low-medium heat, add eggs and stir slowly with a spatula until just set and creamy. Remove from heat before fully set."},{"step":5,"instruction":"Warm akara in a dry pan for 2 minutes or in oven at 180C for 5 minutes if pre-made."},{"step":6,"instruction":"Arrange everything on a plate: fish, eggs, plantain, akara, and roasted tomatoes. Serve immediately."}]'::jsonb,
  680, 42, 58, 28, 7,
  ARRAY['nigerian','breakfast','high-protein','fish','plantain','performance'],
  true, 'photo'
),

-- 4. Beetroot & Passion Fruit Smoothie
(
  'Beetroot & Passion Fruit Smoothie',
  'A vibrant deep-red smoothie combining raw beetroot, passion fruit, and banana. Rich in nitrates for blood flow, antioxidants, and natural energy. Great pre-workout drink.',
  'International',
  'snack',
  5, 0, 1,
  '1 cup (350ml)',
  '[{"item":"raw beetroot, peeled and chopped","quantity":80,"unit":"g"},{"item":"passion fruit pulp","quantity":2,"unit":"fruits"},{"item":"banana","quantity":0.5,"unit":"medium"},{"item":"cold water or coconut water","quantity":200,"unit":"ml"},{"item":"ice cubes","quantity":4,"unit":"pieces"},{"item":"honey (optional)","quantity":1,"unit":"tsp"}]'::jsonb,
  '[{"step":1,"instruction":"Peel and chop beetroot into small chunks. If using a standard blender (not high-powered), boil beetroot for 10 minutes first and cool before blending."},{"step":2,"instruction":"Halve passion fruits and scoop out pulp including seeds."},{"step":3,"instruction":"Add beetroot, passion fruit pulp, banana, water, and ice to blender."},{"step":4,"instruction":"Blend on high for 60-90 seconds until completely smooth. Add honey if desired."},{"step":5,"instruction":"Pour into a glass or cup and serve immediately. Can be stored in fridge for up to 4 hours."}]'::jsonb,
  145, 2, 32, 1, 4,
  ARRAY['smoothie','drink','pre-workout','nitric-oxide','vegan','blood-flow'],
  true, 'photo'
),

-- 5. Spinach & Cheese Frittata
(
  'Spinach & Cheese Frittata',
  'A thick oven-baked frittata loaded with fresh spinach and melted cheese. High in protein, low in carbs, ideal for a muscle-building breakfast or light lunch.',
  'Mediterranean',
  'breakfast',
  5, 15, 2,
  '1 half (~300g)',
  '[{"item":"eggs","quantity":4,"unit":"large"},{"item":"fresh spinach","quantity":100,"unit":"g"},{"item":"mozzarella or cheddar, grated","quantity":60,"unit":"g"},{"item":"olive oil","quantity":15,"unit":"ml"},{"item":"garlic clove, minced","quantity":1,"unit":"clove"},{"item":"salt and black pepper","quantity":1,"unit":"pinch"},{"item":"chilli flakes (optional)","quantity":0.25,"unit":"tsp"}]'::jsonb,
  '[{"step":1,"instruction":"Preheat grill (broiler) to high. Heat olive oil in an oven-safe frying pan over medium heat."},{"step":2,"instruction":"Add garlic and saute for 30 seconds. Add spinach and cook, stirring, for 2 minutes until wilted. Season with salt, pepper, and chilli flakes."},{"step":3,"instruction":"Spread spinach evenly across the pan. Whisk eggs with a pinch of salt and pour over the spinach."},{"step":4,"instruction":"Cook on hob for 3-4 minutes until the edges are set but the centre is still slightly wet."},{"step":5,"instruction":"Scatter cheese evenly over the top. Transfer pan under the grill for 4-5 minutes until cheese is golden and bubbling and the centre is fully set."},{"step":6,"instruction":"Allow to cool slightly before slicing. Serve directly from the pan."}]'::jsonb,
  340, 24, 4, 26, 2,
  ARRAY['eggs','breakfast','high-protein','low-carb','keto','vegetarian'],
  true, 'photo'
),

-- 6. Chicken Schnitzel with Mozzarella & Spinach Salad
(
  'Chicken Schnitzel with Mozzarella Salad',
  'A crispy golden chicken schnitzel paired with a fresh salad of baby spinach, rocket, mozzarella, radicchio, and cucumber with a light olive oil dressing. High protein, balanced macros.',
  'European',
  'lunch',
  15, 12, 1,
  '1 schnitzel + salad (~450g)',
  '[{"item":"chicken breast, butterflied and flattened","quantity":180,"unit":"g"},{"item":"breadcrumbs","quantity":40,"unit":"g"},{"item":"egg, beaten","quantity":1,"unit":"large"},{"item":"plain flour","quantity":20,"unit":"g"},{"item":"baby spinach","quantity":50,"unit":"g"},{"item":"rocket (arugula)","quantity":30,"unit":"g"},{"item":"fresh mozzarella, torn","quantity":80,"unit":"g"},{"item":"radicchio, roughly torn","quantity":30,"unit":"g"},{"item":"cucumber, sliced","quantity":40,"unit":"g"},{"item":"olive oil","quantity":20,"unit":"ml"},{"item":"vegetable oil for frying","quantity":30,"unit":"ml"},{"item":"lemon juice","quantity":10,"unit":"ml"},{"item":"salt and pepper","quantity":1,"unit":"pinch"}]'::jsonb,
  '[{"step":1,"instruction":"Place chicken breast between two sheets of cling film and pound to 5mm thickness using a rolling pin or meat mallet."},{"step":2,"instruction":"Set up three shallow dishes: one with flour, one with beaten egg, one with breadcrumbs. Season flour with salt and pepper."},{"step":3,"instruction":"Coat chicken in flour (shake off excess), dip in egg, then press firmly into breadcrumbs to coat evenly."},{"step":4,"instruction":"Heat vegetable oil in a wide frying pan over medium-high heat. Fry schnitzel for 4-5 minutes per side until deep golden and cooked through (internal temp 74C). Drain on paper towel."},{"step":5,"instruction":"Combine spinach, rocket, radicchio, and cucumber in a bowl. Add mozzarella. Drizzle with olive oil and lemon juice, season, and toss gently."},{"step":6,"instruction":"Plate the schnitzel alongside the salad and serve immediately with a wedge of lemon."}]'::jsonb,
  520, 45, 22, 28, 4,
  ARRAY['chicken','lunch','high-protein','salad','european'],
  true, 'photo'
),

-- 7. Tomato & Feta Frittata
(
  'Tomato & Feta Frittata',
  'A thick, golden frittata baked with roasted cherry tomatoes and chunks of salty feta. Made with garlic for an added testosterone-supportive benefit. Low carb, high protein.',
  'Mediterranean',
  'breakfast',
  10, 20, 4,
  '1 quarter slice (~200g)',
  '[{"item":"eggs","quantity":6,"unit":"large"},{"item":"cherry tomatoes, halved","quantity":150,"unit":"g"},{"item":"feta cheese, crumbled","quantity":100,"unit":"g"},{"item":"garlic cloves, minced","quantity":2,"unit":"cloves"},{"item":"olive oil","quantity":20,"unit":"ml"},{"item":"dried oregano","quantity":1,"unit":"tsp"},{"item":"salt and black pepper","quantity":1,"unit":"pinch"}]'::jsonb,
  '[{"step":1,"instruction":"Preheat oven to 190C. Heat olive oil in an oven-safe frying pan over medium heat."},{"step":2,"instruction":"Saute garlic for 30 seconds until fragrant. Add cherry tomatoes cut-side down and cook for 2 minutes until they start to soften and release juices."},{"step":3,"instruction":"Whisk eggs with salt, pepper, and oregano. Pour over the tomatoes in the pan."},{"step":4,"instruction":"Crumble feta evenly across the top of the egg mixture."},{"step":5,"instruction":"Cook on the hob for 2 minutes until edges just set, then transfer to oven."},{"step":6,"instruction":"Bake for 15-18 minutes until puffed, golden on top, and fully set in the centre. Insert a knife - it should come out clean."},{"step":7,"instruction":"Allow to cool for 5 minutes before slicing into quarters. Serve warm or at room temperature."}]'::jsonb,
  280, 18, 6, 20, 1,
  ARRAY['eggs','breakfast','high-protein','low-carb','mediterranean','feta'],
  true, 'photo'
),

-- 8. Spicy Korean Chicken Rice Bowl
(
  'Spicy Korean Chicken Rice Bowl',
  'Tender marinated chicken thighs in a gochujang glaze served over jasmine rice with a soft fried egg, sesame seeds, spring onions, and red chilli. Balanced macros, bold flavour.',
  'Korean',
  'lunch',
  15, 20, 1,
  '1 bowl (~500g)',
  '[{"item":"chicken thighs, boneless skinless, cut into chunks","quantity":200,"unit":"g"},{"item":"jasmine rice, cooked","quantity":150,"unit":"g"},{"item":"egg","quantity":1,"unit":"large"},{"item":"gochujang paste","quantity":20,"unit":"g"},{"item":"soy sauce","quantity":15,"unit":"ml"},{"item":"sesame oil","quantity":10,"unit":"ml"},{"item":"honey","quantity":10,"unit":"g"},{"item":"garlic cloves, minced","quantity":2,"unit":"cloves"},{"item":"fresh ginger, grated","quantity":5,"unit":"g"},{"item":"spring onions, sliced","quantity":20,"unit":"g"},{"item":"red chilli, sliced","quantity":1,"unit":"small"},{"item":"sesame seeds","quantity":5,"unit":"g"},{"item":"vegetable oil","quantity":15,"unit":"ml"}]'::jsonb,
  '[{"step":1,"instruction":"Mix gochujang, soy sauce, sesame oil, honey, garlic, and ginger in a bowl to make the marinade. Toss chicken chunks in the marinade and leave for at least 10 minutes (or overnight in fridge)."},{"step":2,"instruction":"Cook rice according to packet instructions. Keep warm."},{"step":3,"instruction":"Heat vegetable oil in a wok or large pan over high heat. Add chicken and marinade, cook for 8-10 minutes, stirring occasionally, until chicken is cooked through and sauce has caramelised."},{"step":4,"instruction":"In a separate small pan, fry egg in a little oil to your preference - sunny side up leaves a runny yolk which mixes into the rice beautifully."},{"step":5,"instruction":"Serve rice in a bowl, top with chicken and all the sauce, then add the fried egg on top."},{"step":6,"instruction":"Garnish with spring onions, red chilli slices, and sesame seeds."}]'::jsonb,
  620, 38, 65, 22, 3,
  ARRAY['korean','lunch','high-protein','spicy','rice','chicken'],
  true, 'photo'
),

-- 9. Moi Moi
(
  'Moi Moi',
  'A classic Nigerian steamed bean pudding made from blended black-eyed peas with peppers, onion, crayfish, and spices. High in plant protein and fibre. Can be eaten alone or as a side dish.',
  'Nigerian',
  'snack',
  30, 40, 6,
  '1 ramekin / portion (~180g)',
  '[{"item":"black-eyed peas (dried)","quantity":300,"unit":"g"},{"item":"red bell pepper","quantity":1,"unit":"large"},{"item":"scotch bonnet pepper","quantity":1,"unit":"small"},{"item":"red onion","quantity":0.5,"unit":"medium"},{"item":"crayfish (dried ground)","quantity":2,"unit":"tbsp"},{"item":"vegetable or chicken stock","quantity":200,"unit":"ml"},{"item":"vegetable oil","quantity":30,"unit":"ml"},{"item":"salt","quantity":1,"unit":"tsp"},{"item":"seasoning cube","quantity":1,"unit":"cube"}]'::jsonb,
  '[{"step":1,"instruction":"Soak dried black-eyed peas in cold water for at least 2 hours or overnight. Drain, then rub between your palms to remove the skins. Rinse and drain well."},{"step":2,"instruction":"Blend the peeled beans with the red pepper, scotch bonnet, and onion, adding stock gradually until you have a smooth, thick paste. The consistency should coat the back of a spoon."},{"step":3,"instruction":"Pour the blended mixture into a large bowl. Add crayfish, vegetable oil, salt, and crumbled seasoning cube. Mix well."},{"step":4,"instruction":"Lightly grease ramekins or use greased foil pouches/cups. Pour in the bean mixture, filling 3/4 full."},{"step":5,"instruction":"Place ramekins in a large pot with 3-4cm of boiling water in the base. Cover tightly and steam on medium heat for 35-40 minutes, topping up water as needed."},{"step":6,"instruction":"Test by inserting a skewer - it should come out clean. Allow to cool slightly before unmoulding. Serve warm."}]'::jsonb,
  220, 14, 28, 6, 8,
  ARRAY['nigerian','snack','high-protein','plant-based','beans','traditional'],
  true, 'photo'
),

-- 10. Lentil Akara Waffle
(
  'Lentil Akara Waffle',
  'A creative fusion of Nigerian akara (bean fritters) made with red lentils and cooked in a waffle iron. Crispy outside, soft inside. Served with peppery rocket and cooling Greek yogurt.',
  'Nigerian-Fusion',
  'breakfast',
  10, 15, 2,
  '1 waffle + salad + yogurt (~280g)',
  '[{"item":"red lentils, dry","quantity":150,"unit":"g"},{"item":"red onion, roughly chopped","quantity":0.5,"unit":"medium"},{"item":"scotch bonnet or chilli","quantity":0.5,"unit":"small"},{"item":"ground crayfish (optional)","quantity":1,"unit":"tsp"},{"item":"vegetable oil","quantity":20,"unit":"ml"},{"item":"salt","quantity":0.5,"unit":"tsp"},{"item":"turmeric","quantity":0.5,"unit":"tsp"},{"item":"rocket (arugula)","quantity":40,"unit":"g"},{"item":"Greek yogurt or sour cream","quantity":80,"unit":"g"}]'::jsonb,
  '[{"step":1,"instruction":"Rinse red lentils and soak in cold water for 1 hour (or use canned lentils, drained). Drain well."},{"step":2,"instruction":"Blend lentils with red onion and scotch bonnet to a thick, smooth batter. It should be thicker than pancake batter."},{"step":3,"instruction":"Stir in crayfish (if using), salt, turmeric, and 10ml of vegetable oil. Mix well."},{"step":4,"instruction":"Preheat waffle iron and brush generously with the remaining oil."},{"step":5,"instruction":"Pour batter into the centre of the waffle iron, close, and cook for 6-8 minutes until golden, crispy, and cooked through. The waffle should release cleanly."},{"step":6,"instruction":"Serve on a plate with a handful of rocket and a generous dollop of Greek yogurt on the side. Season the yogurt with a pinch of salt and pepper."}]'::jsonb,
  380, 22, 48, 10, 12,
  ARRAY['nigerian','breakfast','high-protein','plant-based','lentils','fusion','high-fibre'],
  true, 'photo'
),

-- 11. Spiced Chicken with Chickpea & Lentil Bowl
(
  'Spiced Chicken with Chickpea & Lentil Bowl',
  'Crispy roasted chicken drumsticks served alongside a warm chickpea and red lentil salad with kidney beans, red onion, tomato, and fresh parsley. Served with a scoop of mashed potato.',
  'Nigerian-Mediterranean',
  'lunch',
  15, 35, 1,
  '1 plate (~550g)',
  '[{"item":"chicken drumsticks","quantity":2,"unit":"pieces"},{"item":"tinned chickpeas, drained","quantity":150,"unit":"g"},{"item":"red lentils, cooked","quantity":80,"unit":"g"},{"item":"red kidney beans, drained","quantity":50,"unit":"g"},{"item":"red onion, diced","quantity":0.5,"unit":"medium"},{"item":"plum tomatoes, diced","quantity":2,"unit":"medium"},{"item":"fresh parsley, chopped","quantity":10,"unit":"g"},{"item":"mashed potato","quantity":100,"unit":"g"},{"item":"olive oil","quantity":20,"unit":"ml"},{"item":"paprika","quantity":1,"unit":"tsp"},{"item":"cumin","quantity":0.5,"unit":"tsp"},{"item":"garlic powder","quantity":0.5,"unit":"tsp"},{"item":"salt and pepper","quantity":1,"unit":"pinch"},{"item":"lemon juice","quantity":10,"unit":"ml"}]'::jsonb,
  '[{"step":1,"instruction":"Preheat oven to 200C. Score the chicken drumsticks with a knife and rub all over with paprika, cumin, garlic powder, salt, pepper, and half the olive oil."},{"step":2,"instruction":"Place drumsticks on a baking tray lined with foil. Roast for 30-35 minutes, turning once halfway, until skin is golden and internal temperature reaches 74C."},{"step":3,"instruction":"Cook red lentils: rinse and simmer in lightly salted water for 10-12 minutes until just tender. Drain."},{"step":4,"instruction":"In a bowl, combine chickpeas, lentils, kidney beans, red onion, and tomato. Dress with remaining olive oil, lemon juice, salt, and pepper. Fold through parsley."},{"step":5,"instruction":"Prepare mashed potato: boil peeled potatoes until tender, drain, mash with butter and a splash of milk. Season well."},{"step":6,"instruction":"Plate the mashed potato, spoon the chickpea salad alongside, and rest the drumsticks on top. Serve immediately."}]'::jsonb,
  580, 44, 52, 18, 14,
  ARRAY['chicken','lunch','high-protein','chickpea','lentils','high-fibre'],
  true, 'photo'
),

-- 12. Loaded Akara Fries
(
  'Loaded Akara Fries',
  'Crispy fries loaded with spiced akara (bean fritters), a rich tomato sauce, creamy garlic mayo, crunchy slaw, fresh coriander, spring onions, and chilli. A bold Nigerian-fusion comfort dish.',
  'Nigerian-Fusion',
  'lunch',
  20, 25, 1,
  '1 box (~500g)',
  '[{"item":"frozen fries or fresh cut chips","quantity":200,"unit":"g"},{"item":"akara (bean fritters), pre-made","quantity":120,"unit":"g"},{"item":"tinned chopped tomatoes","quantity":100,"unit":"g"},{"item":"red onion, diced","quantity":0.25,"unit":"medium"},{"item":"scotch bonnet, minced","quantity":0.5,"unit":"small"},{"item":"mayonnaise","quantity":30,"unit":"g"},{"item":"garlic clove, minced","quantity":1,"unit":"clove"},{"item":"red cabbage, shredded","quantity":40,"unit":"g"},{"item":"carrot, grated","quantity":30,"unit":"g"},{"item":"spring onions, sliced","quantity":20,"unit":"g"},{"item":"fresh coriander, chopped","quantity":10,"unit":"g"},{"item":"red chilli, sliced","quantity":1,"unit":"small"},{"item":"vegetable oil","quantity":20,"unit":"ml"},{"item":"salt and pepper","quantity":1,"unit":"pinch"}]'::jsonb,
  '[{"step":1,"instruction":"Cook fries: deep fry at 180C for 4-5 minutes until golden and crispy, or oven bake at 220C for 20-25 minutes, turning once."},{"step":2,"instruction":"Make tomato sauce: saute onion and scotch bonnet in oil for 2 minutes. Add chopped tomatoes, season with salt, and simmer for 8-10 minutes until thickened."},{"step":3,"instruction":"Make garlic mayo: mix mayonnaise with minced garlic and a squeeze of lemon juice."},{"step":4,"instruction":"Make slaw: toss shredded red cabbage and grated carrot with a pinch of salt and a squeeze of lemon."},{"step":5,"instruction":"Warm akara in a dry pan or oven for 3-4 minutes until crispy."},{"step":6,"instruction":"Pile fries into a bowl or tray. Layer slaw on top, then akara, then spoon over the tomato sauce. Drizzle generously with garlic mayo."},{"step":7,"instruction":"Finish with spring onions, coriander, and sliced chilli. Serve immediately."}]'::jsonb,
  680, 18, 78, 34, 9,
  ARRAY['nigerian','lunch','comfort','fusion','fries','beans'],
  true, 'photo'
),

-- 13. Jollof Rice with Roasted Chicken & Fried Plantain
(
  'Jollof Rice with Roasted Chicken & Fried Plantain',
  'Classic West African party jollof rice served with oven-roasted chicken pieces and sweet fried plantain. A complete, satisfying meal high in protein and carbohydrates for post-training recovery.',
  'Nigerian',
  'dinner',
  20, 50, 1,
  '1 plate (rice + chicken + plantain, ~600g)',
  '[{"item":"long grain parboiled rice","quantity":100,"unit":"g"},{"item":"tinned plum tomatoes","quantity":200,"unit":"g"},{"item":"red bell pepper","quantity":1,"unit":"medium"},{"item":"scotch bonnet","quantity":1,"unit":"small"},{"item":"red onion","quantity":1,"unit":"medium"},{"item":"chicken pieces (legs and thighs)","quantity":200,"unit":"g"},{"item":"ripe plantain","quantity":1,"unit":"medium"},{"item":"vegetable oil","quantity":40,"unit":"ml"},{"item":"chicken stock","quantity":200,"unit":"ml"},{"item":"tomato paste","quantity":30,"unit":"g"},{"item":"garlic cloves, minced","quantity":2,"unit":"cloves"},{"item":"bay leaves","quantity":2,"unit":"leaves"},{"item":"seasoning cube","quantity":1,"unit":"cube"},{"item":"thyme, dried","quantity":1,"unit":"tsp"},{"item":"paprika","quantity":1,"unit":"tsp"},{"item":"salt and pepper","quantity":1,"unit":"pinch"}]'::jsonb,
  '[{"step":1,"instruction":"Marinate chicken with salt, pepper, paprika, thyme, garlic, and half the oil. Roast in oven at 200C for 35-40 minutes, turning once, until golden and cooked through."},{"step":2,"instruction":"Blend tomatoes, red pepper, scotch bonnet, and half the onion into a smooth puree."},{"step":3,"instruction":"Dice remaining onion. Heat oil in a heavy-based pot over medium-high heat. Fry onion for 3 minutes. Add tomato paste and stir for 2 minutes. Pour in blended tomato mixture."},{"step":4,"instruction":"Cook the tomato base on high heat, stirring regularly, for 15-20 minutes until the raw tomato smell is gone and oil floats on top."},{"step":5,"instruction":"Add rinsed rice to the pot, pour in chicken stock, add bay leaves and seasoning cube. Stir once, cover tightly, and cook on very low heat for 25-30 minutes. Do not lift the lid for the first 20 minutes."},{"step":6,"instruction":"Meanwhile, slice plantain diagonally and shallow fry in oil for 2-3 minutes each side until golden."},{"step":7,"instruction":"Fluff jollof rice with a fork. Plate with chicken pieces and fried plantain alongside."}]'::jsonb,
  720, 42, 85, 20, 5,
  ARRAY['nigerian','dinner','jollof','chicken','plantain','post-workout','traditional'],
  true, 'photo'
),

-- 14. Grilled Mackerel with Scrambled Eggs & Sauteed Greens
(
  'Grilled Mackerel with Scrambled Eggs & Sauteed Greens',
  'A nutritional powerhouse: omega-3 rich grilled mackerel fillet, creamy scrambled eggs with peppers and tomatoes, and a colourful saute of spinach, chard, spring onions, and peppers. High protein, high micronutrients.',
  'Nigerian-British',
  'breakfast',
  10, 15, 1,
  '1 plate (~480g)',
  '[{"item":"mackerel fillet","quantity":180,"unit":"g"},{"item":"eggs","quantity":3,"unit":"large"},{"item":"red pepper, diced","quantity":50,"unit":"g"},{"item":"plum tomato, diced","quantity":1,"unit":"medium"},{"item":"baby spinach","quantity":50,"unit":"g"},{"item":"rainbow chard or mixed greens","quantity":60,"unit":"g"},{"item":"spring onions, sliced","quantity":20,"unit":"g"},{"item":"yellow pepper, sliced","quantity":40,"unit":"g"},{"item":"butter","quantity":15,"unit":"g"},{"item":"olive oil","quantity":15,"unit":"ml"},{"item":"salt and black pepper","quantity":1,"unit":"pinch"},{"item":"lemon wedge","quantity":1,"unit":"piece"}]'::jsonb,
  '[{"step":1,"instruction":"Season mackerel with salt, pepper, and a drizzle of oil. Grill or pan-fry skin-side down on medium-high heat for 4 minutes, then flip and cook for 3 more minutes until cooked through."},{"step":2,"instruction":"Heat olive oil in a separate pan over medium heat. Add spring onions and yellow pepper, saute for 2 minutes. Add spinach and chard and toss until wilted, 2-3 minutes. Season and remove from heat."},{"step":3,"instruction":"Whisk eggs with a pinch of salt. Melt butter in a small pan over low heat. Add eggs and stir slowly with a spatula, folding gently every 30 seconds."},{"step":4,"instruction":"When eggs are almost set, add diced red pepper and tomato. Continue stirring gently for 1 more minute until eggs are just cooked but still creamy."},{"step":5,"instruction":"Plate everything together: mackerel fillet, creamy scrambled eggs, and sauteed greens. Add a lemon wedge alongside the mackerel."}]'::jsonb,
  480, 42, 12, 30, 5,
  ARRAY['fish','breakfast','high-protein','omega-3','eggs','greens','performance'],
  true, 'photo'
),

-- 15. Herb Grilled Chicken with Feta Salad
(
  'Herb Grilled Chicken with Feta Salad',
  'Juicy herb-marinated chicken breast served with a crisp mixed leaf, cucumber, and feta salad. Finished with a generous spoon of Greek yogurt. High protein, low carb, excellent for cutting or maintenance.',
  'Mediterranean',
  'lunch',
  10, 15, 1,
  '1 plate (~450g)',
  '[{"item":"chicken breast","quantity":200,"unit":"g"},{"item":"mixed salad leaves","quantity":60,"unit":"g"},{"item":"feta cheese, cubed","quantity":80,"unit":"g"},{"item":"cucumber, sliced","quantity":60,"unit":"g"},{"item":"Greek yogurt","quantity":100,"unit":"g"},{"item":"dried oregano","quantity":1,"unit":"tsp"},{"item":"dried thyme","quantity":0.5,"unit":"tsp"},{"item":"garlic powder","quantity":0.5,"unit":"tsp"},{"item":"olive oil","quantity":15,"unit":"ml"},{"item":"lemon juice","quantity":15,"unit":"ml"},{"item":"salt and pepper","quantity":1,"unit":"pinch"}]'::jsonb,
  '[{"step":1,"instruction":"Mix oregano, thyme, garlic powder, salt, pepper, half the olive oil, and half the lemon juice. Coat chicken breast in the herb marinade and leave for at least 10 minutes."},{"step":2,"instruction":"Grill or pan-fry chicken over medium-high heat for 6-7 minutes per side until golden and cooked through (internal temp 74C). Allow to rest for 3 minutes before slicing."},{"step":3,"instruction":"Toss salad leaves and cucumber in remaining olive oil, lemon juice, and a pinch of salt."},{"step":4,"instruction":"Arrange salad on a plate, scatter feta over the top."},{"step":5,"instruction":"Slice chicken and lay over or alongside the salad. Add a generous spoon of Greek yogurt to the plate. Season the yogurt with a pinch of salt and a drizzle of olive oil."}]'::jsonb,
  480, 52, 10, 26, 3,
  ARRAY['chicken','lunch','high-protein','low-carb','mediterranean','salad','feta','cutting'],
  true, 'photo'
),

-- 16. Oven-Baked Spiced Salmon
(
  'Oven-Baked Spiced Salmon',
  'A whole salmon fillet baked in foil with a crust of paprika, cumin, garlic, and chilli. Rich in omega-3 fatty acids and testosterone-supportive nutrients. Minimal prep, maximum nutrition.',
  'Mediterranean',
  'dinner',
  8, 20, 2,
  '1 half fillet (~150g)',
  '[{"item":"salmon fillet, whole side","quantity":300,"unit":"g"},{"item":"paprika (smoked)","quantity":1.5,"unit":"tsp"},{"item":"ground cumin","quantity":0.5,"unit":"tsp"},{"item":"chilli powder","quantity":0.5,"unit":"tsp"},{"item":"garlic powder","quantity":1,"unit":"tsp"},{"item":"dried oregano","quantity":0.5,"unit":"tsp"},{"item":"olive oil","quantity":20,"unit":"ml"},{"item":"lemon","quantity":0.5,"unit":"piece"},{"item":"salt and black pepper","quantity":1,"unit":"pinch"}]'::jsonb,
  '[{"step":1,"instruction":"Preheat oven to 200C. Line a baking tray with foil, leaving enough to fold over and seal the fish."},{"step":2,"instruction":"Mix paprika, cumin, chilli powder, garlic powder, oregano, salt, and pepper in a small bowl. Stir in olive oil to form a paste."},{"step":3,"instruction":"Pat salmon dry with kitchen paper. Place skin-side down on the foil. Spread the spice paste evenly over the entire top surface using the back of a spoon. Squeeze lemon juice over the top."},{"step":4,"instruction":"Fold the foil loosely over the salmon to seal, creating a parcel. This traps steam and keeps the fish moist."},{"step":5,"instruction":"Bake for 15 minutes, then open the foil and return to the oven for a further 4-5 minutes to caramelise the spice crust."},{"step":6,"instruction":"Remove from oven and rest for 2 minutes. Serve directly from the foil with vegetables, salad, or rice on the side."}]'::jsonb,
  420, 48, 4, 24, 1,
  ARRAY['fish','dinner','high-protein','omega-3','low-carb','testosterone','baked'],
  true, 'photo'
);
