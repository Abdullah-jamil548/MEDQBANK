import '../../domain/entities/study_book.dart';

abstract final class HistologyBook {
  static const StudyBook meta = StudyBook(
    id: 'medqbank-histology',
    title: 'Medical Histology',
    author: 'MedQBank Faculty Notes',
    subject: 'Histology',
    yearLabel: '1st / 2nd Year',
    blurb:
        'In-app MBBS companion for microscopic anatomy. Read inside the app, highlight lines, add notes, and bookmark chapters — no extra PDF needed.',
  );

  static const List<BookChapter> chapters = [
    BookChapter(
      id: 'h01',
      title: 'How to use this book',
      subtitle: 'Reader, highlights, and notes',
      body: '''
This is MedQBank’s bundled Histology companion. It lives inside the app, so you can open it offline after install.

To highlight: press and hold any line, then choose Highlight. Amber is for definitions, mint for clinical correlation, and rose for viva traps.

To add a note: select the same text and choose Note. Your words stay attached to that line.

Bookmark a chapter from the header when you want to return quickly. Progress is saved on this device.

This book is original faculty-style notes for MBBS revision. It is not a scan or reprint of any commercial textbook.
''',
    ),
    BookChapter(
      id: 'h02',
      title: 'Introduction to histology',
      subtitle: 'Why microscopic anatomy matters',
      body: '''
Histology is the study of tissues — groups of similar cells and their extracellular matrix organised to perform a function. Gross anatomy shows you the organ; histology shows you why the organ works.

Four basic tissues build the body: epithelium, connective tissue, muscle, and nervous tissue. Organs are mixtures of these four, arranged in a pattern you can recognise on a slide.

A useful habit in the lab is to ask three questions on every field: What is the lining? What is the supporting tissue? What specialised cells are present? Those three answers usually name the organ.

Clinical work depends on this skill. Biopsies, Pap smears, bone-marrow films, and frozen sections are histology in the clinic. If you can describe a tissue clearly, you can follow a pathology report.

Light microscopy with haematoxylin and eosin (H&E) is the default. Haematoxylin stains nuclei blue-purple. Eosin stains cytoplasm and collagen pink. Special stains and immunohistochemistry are add-ons when H&E is not enough.

Resolution of the light microscope is about 0.2 micrometres. Electron microscopy is used when you need membranes, junctions, or basement-membrane fine structure.

Carry a mental scale: a red cell is about 7 micrometres. If a structure is “about two RBCs wide”, you already have a measurement without a micrometer.
''',
    ),
    BookChapter(
      id: 'h03',
      title: 'The cell on a slide',
      subtitle: 'What you can actually see',
      body: '''
On H&E you do not see every organelle. You see nucleus, nucleolus, cytoplasm staining, and cell shape. Train your eye on those first.

A vesicular nucleus with a prominent nucleolus often means the cell is active in protein synthesis. A dark, condensed nucleus may mean a resting cell, a dying cell, or a cell with little cytoplasm — context decides.

Basophilic cytoplasm (blue-purple) usually means abundant rough endoplasmic reticulum and ribosomes — plasma cells and pancreatic acinar cells are classic. Eosinophilic cytoplasm often means mitochondria, lysosomes, or stored protein.

The plasma membrane is rarely a crisp line on light microscopy. You infer it from cell borders. Brush borders, cilia, and stereocilia are the exceptions you must name.

The basement membrane is a thin eosinophilic line under epithelium. PAS stain makes it obvious because of glycoproteins. In kidney glomeruli and skin, basement-membrane quality is a clinical question, not only a lab curiosity.

Mitotic figures belong in renewal tissues: epidermis, gut crypts, bone marrow. Frequent mitoses in a tissue that should be quiet are a red flag in pathology.

Cell death has patterns. Necrosis looks messy, with faded nuclei and inflamed neighbours. Apoptosis looks tidy: a shrink cell, pyknotic nucleus, little inflammation. You will meet both in later systemic chapters.
''',
    ),
    BookChapter(
      id: 'h04',
      title: 'Epithelial tissue',
      subtitle: 'Coverings, linings, and polarity',
      body: '''
Epithelium covers surfaces, lines cavities, and forms glands. Cells sit on a basement membrane, are tightly packed, and show polarity: an apical side and a basal side.

Simple epithelium is one cell thick. Stratified epithelium has stacked layers. Pseudostratified epithelium looks layered because nuclei sit at different heights, but every cell touches the basement membrane.

Squamous cells are flat, cuboidal cells are square, columnar cells are tall. Combine shape and layering and you can name almost any lining.

Simple squamous epithelium is built for exchange: alveoli, endothelium, mesothelium. Simple cuboidal is common in ducts and kidney tubules. Simple columnar lines much of the gut and often carries a brush border or goblet cells.

Pseudostratified ciliated columnar epithelium with goblet cells is the respiratory lining of the conducting airways. Mucus traps particles; cilia sweep the mucus toward the pharynx.

Stratified squamous epithelium resists abrasion. Keratinised type covers skin. Non-keratinised type lines the oral cavity, oesophagus, and vagina — wet surfaces that still need toughness.

Transitional epithelium (urothelium) lines the urinary tract. Surface umbrella cells stretch as the bladder fills. Binucleate surface cells are a useful clue.

Junctions keep the sheet sealed and the sheet together. Tight junctions control paracellular flow. Desmosomes give strength. Hemidesmosomes nail the cell to the basement membrane. Gap junctions allow small-molecule talk between neighbours.

If epithelium is malignant, the basement membrane is the line between in situ and invasion. That single histological idea drives a large part of cancer staging talk in viva.
''',
    ),
    BookChapter(
      id: 'h05',
      title: 'Glands',
      subtitle: 'Exocrine patterns you must recognise',
      body: '''
Glands are epithelial in origin. Endocrine glands lose their ducts and secrete into blood. Exocrine glands keep a duct and secrete onto a surface.

Unicellular exocrine glands are goblet cells. Multicellular glands are classified by duct branching (simple vs compound) and by secretory shape (tubular, acinar, tubuloacinar).

Serous cells make watery, enzyme-rich secretions and stain darker. Mucous cells make mucin and look pale and washed-out on H&E. Mixed glands, such as submandibular, show both and often have serous demilunes.

Mode of secretion has three classic names. Merocrine (eccrine) secretion is exocytosis — most sweat glands and the pancreas. Apocrine secretion pinches off apical cytoplasm — mammary lipid secretion is the usual example taught. Holocrine secretion is cell suicide that dumps the whole cell — sebaceous glands.

Myoepithelial cells hug acini in salivary, lacrimal, and mammary glands. They are contractile and help expel product. In breast pathology they help tell in situ from invasive disease.

Duct epithelium usually starts cuboidal and may become columnar as ducts widen. Know the difference between a secretory acinus and a duct: acini are berry-shaped and packed with secretory granules; ducts have a clearer lumen and a different lining.

Clinical correlation: dry mouth after damage to salivary parenchyma, cystic fibrosis changing mucus, and duct obstruction causing painful swelling are all gland histology in real life.
''',
    ),
    BookChapter(
      id: 'h06',
      title: 'Connective tissue proper',
      subtitle: 'Cells, fibres, and ground substance',
      body: '''
Connective tissue proper holds other tissues, stores energy, and hosts immune cells. It has three ingredients: cells, fibres, and ground substance.

Fibroblasts make collagen, elastin, and ground substance. When active they are plump; when quiet they look like thin nuclei in pink collagen.

Collagen type I is the thick eosinophilic fibre of dermis, tendon, and bone. Type II is cartilage. Type III (reticular) forms delicate nets in lymph nodes and marrow, best seen with silver stain. Type IV sits in basement membranes.

Elastic fibres recoil. You need special stains (Verhoeff, orcein) to see them well. Large arteries and lung depend on them.

Ground substance is glycosaminoglycans, proteoglycans, and glycoproteins. It looks empty on H&E. That “empty” space is why oedema can swell a tissue so fast.

Loose areolar tissue is the packing around vessels and under epithelium. Dense regular connective tissue is tendon and ligament — fibres in parallel, cells in rows. Dense irregular connective tissue is dermis — fibres woven in many directions so skin resists pull from all sides.

Adipose tissue is connective tissue specialised for fat storage, cushioning, and endocrine signalling (leptin and others). White fat has a single large droplet. Brown fat has many droplets and mitochondria for heat.

Resident and immigrant cells mix here: macrophages, mast cells, plasma cells, lymphocytes. Mast cells sit near vessels and dump histamine. Plasma cells have a clock-face nucleus and a pale Golgi halo — a favourite viva identification.

Scurvy, Ehlers–Danlos syndromes, and keloids are collagen stories. If a question mentions wound strength or vitamin C, think collagen cross-linking.
''',
    ),
    BookChapter(
      id: 'h07',
      title: 'Cartilage',
      subtitle: 'Avascular support tissue',
      body: '''
Cartilage is firm, flexible, and avascular. Chondrocytes live in lacunae and are fed by diffusion through matrix. That is why cartilage heals poorly.

Three types: hyaline, elastic, and fibrocartilage.

Hyaline cartilage is the default. Glassy matrix, type II collagen, perichondrium on most surfaces. You find it in the fetal skeleton, articular surfaces, trachea, bronchi, and growth plates. Articular hyaline cartilage has no perichondrium — an important exception.

Elastic cartilage adds elastic fibres. Pinna, epiglottis, and the auditory tube keep shape and bounce back. A stain for elastin makes the diagnosis easy.

Fibrocartilage is a hybrid: cartilage cells in rows plus abundant type I collagen. No perichondrium. Intervertebral discs, pubic symphysis, and menisci take compression and tension together.

Isogenous groups are clusters of chondrocytes that just divided. Territorial matrix around them stains differently from interterritorial matrix.

Calcification of hyaline cartilage is normal in endochondral ossification and abnormal in some degenerative joints. Do not call calcified cartilage “bone” until osteoblasts and osteoid appear.

Clinical anchors: osteoarthritis starts in articular cartilage. A herniated disc is fibrocartilage failure. Relapsing polychondritis attacks cartilage of ear and airway.
''',
    ),
    BookChapter(
      id: 'h08',
      title: 'Bone',
      subtitle: 'Mineralised connective tissue',
      body: '''
Bone is mineralised connective tissue with a vascular supply and constant remodelling. Cells: osteoblasts (build), osteocytes (maintain, live in lacunae), osteoclasts (resorb, multinucleate, Howship’s lacunae).

Osteoid is unmineralised matrix, mostly type I collagen. Mineral is hydroxyapatite. On H&E, mature bone looks eosinophilic; mineral is better discussed than seen as crystals.

Compact bone is organised in osteons (Haversian systems): concentric lamellae around a central canal with vessels. Canaliculi connect osteocytes. Volkmann canals link neighbouring osteons.

Spongy (cancellous) bone is trabeculae with marrow spaces. Trabeculae still have lamellae and osteocytes, but not always full osteons.

Two development routes. Intramembranous ossification: mesenchyme to bone, as in many skull bones and the clavicle. Endochondral ossification: hyaline model to bone, as in long bones. Know the growth-plate zones in order: resting, proliferation, hypertrophy, calcification, ossification.

Periosteum covers outer bone except articular surfaces. Endosteum lines inner surfaces. Both hold osteoprogenitor cells.

Woven bone is immature and haphazard. Lamellar bone is mature and organised. Fracture callus starts woven, then remodels to lamellar.

Clinical: osteoporosis is too little bone mass. Osteomalacia/rickets is too little mineral in osteoid. Osteopetrosis is failed osteoclasts. A fracture that does not get blood (femoral head, scaphoid) risks avascular necrosis — histology follows blood supply.
''',
    ),
    BookChapter(
      id: 'h09',
      title: 'Muscle tissue',
      subtitle: 'Skeletal, cardiac, and smooth',
      body: '''
Muscle turns chemical energy into force. Three types differ in striations, nuclei, and control.

Skeletal muscle is striated, voluntary, and multinucleate with nuclei at the periphery. A muscle fibre is the cell. Myofibrils pack the cytoplasm. The sarcomere runs Z disc to Z disc: actin thin filaments, myosin thick filaments, and the banding you must recite (A, I, H, M).

Connective tissue wrapping: endomysium around each fibre, perimysium around a fascicle, epimysium around the whole muscle. Nerves and vessels travel in these sheaths.

The neuromuscular junction is a specialised synapse. Acetylcholine opens nicotinic receptors; acetylcholinesterase clears the signal. Myasthenia gravis lives at this junction.

Cardiac muscle is striated, involuntary, and usually one central nucleus per cell. Cells branch and join at intercalated discs. Discs combine fascia adherens, desmosomes, and gap junctions so the myocardium pulls as a unit and shares ions.

Purkinje fibres are specialised cardiac myocytes: larger, paler, glycogen-rich, fewer myofibrils. They sit under endocardium and run the electrical highway.

Smooth muscle is non-striated, involuntary, with a single central nucleus in a spindle cell. Dense bodies play the role of Z discs. It lines gut, vessels, airway, and uterus. Caveolae indent the membrane.

Hypertrophy vs hyperplasia: skeletal muscle fibres enlarge; they do not divide in ordinary adult repair. Smooth muscle can do both. Cardiac muscle hypertrophies under load and has very limited division.

Rigor, dystrophy, and infarct questions all start from these cell features. If nuclei are peripheral and the cell is long, you are in skeletal muscle. If discs are present, you are in heart.
''',
    ),
    BookChapter(
      id: 'h10',
      title: 'Nervous tissue',
      subtitle: 'Neurons, glia, and peripheral nerve',
      body: '''
Nervous tissue is neurons plus glia. Neurons receive, decide, and send. Glia support, insulate, and defend.

A typical neuron has dendrites, a soma, and one axon. Nissl substance is rough endoplasmic reticulum in the soma and dendrites — not in the axon hillock. That detail is a common identification point.

Synapses may be chemical or electrical. Most teaching cases are chemical: vesicles, cleft, receptors.

CNS glia: astrocytes (blood–brain barrier support, gliosis after injury), oligodendrocytes (myelin in CNS, one cell to many axons), microglia (immune, mesodermal origin), ependymal cells (ventricle lining).

PNS glia: Schwann cells (myelin in PNS, one cell to one internode) and satellite cells around ganglion neurons.

Myelin is lipid-rich wrapping that speeds conduction by saltatory jumps at nodes of Ranvier. Demyelination in CNS (multiple sclerosis) and PNS (Guillain–Barré) are different diseases because different cells make the myelin.

A peripheral nerve in cross-section shows axons, myelin, Schwann nuclei, and three wrappings: endoneurium, perineurium, epineurium. Perineurium is the diffusion barrier of the nerve.

Ganglia: dorsal-root ganglia have large sensory neurons with satellite-cell rings and central nuclei. Autonomic ganglia have more eccentric nuclei and synapses on the soma.

Grey matter is neuron-rich; white matter is axon- and myelin-rich. Cerebellar cortex has a signature three-layer look with Purkinje cells in a single row — an identification classic.

Blood–brain barrier: tight-junction endothelium, basement membrane, and astrocyte end-feet. Lipid-soluble drugs cross; many others do not. That is histology with pharmacology attached.
''',
    ),
    BookChapter(
      id: 'h11',
      title: 'Blood and haemopoiesis',
      subtitle: 'Cells you already count in clinic',
      body: '''
Blood is a fluid connective tissue: plasma plus formed elements.

Erythrocytes are anucleate biconcave discs, about 7.5 micrometres, packed with haemoglobin. On a film they should have central pallor of about one-third. Too much pallor suggests hypochromia. Stacks (rouleaux) appear in high protein states.

Leukocytes divide into granulocytes and agranulocytes.

Neutrophils: multilobed nucleus, pale granules, first responders to bacteria. Band forms increase in acute infection.

Eosinophils: bilobed nucleus, chunky red granules. Parasites and type I hypersensitivity.

Basophils: rare, dark granules that can hide the nucleus, histamine and heparin. Related in function to mast cells, but mast cells live in tissue.

Lymphocytes: round dense nucleus, thin cytoplasm. Size varies. B, T, and NK types are not separable on routine stain.

Monocytes: largest circulating WBC, kidney-shaped nucleus, become macrophages in tissue.

Platelets are megakaryocyte fragments. They are small, anucleate, and essential for haemostasis.

Bone marrow is the factory. Red marrow is haematopoietic; yellow marrow is fat. As you age, fat expands in long-bone shafts. Iliac crest remains a biopsy site.

Haemopoiesis after birth is mainly marrow. In stress, spleen and liver may resume extramedullary production — you will see this idea again in pathology.

Megakaryocytes are giant, multilobed, and sit near sinusoids so platelets can bud into blood. If you see a huge cell in marrow, that is the first guess.

Clinical films: iron deficiency, B12/folate megaloblastic change, leukaemia blasts, and malaria inside RBCs. Histology and haematology share the same cells.
''',
    ),
    BookChapter(
      id: 'h12',
      title: 'Lymphoid tissue',
      subtitle: 'Nodes, spleen, thymus, MALT',
      body: '''
Lymphoid tissue filters antigen and houses lymphocytes.

A lymph node has a capsule, cortex, paracortex, and medulla. Afferent lymphatics enter the convex side. Efferent lymph leaves at the hilum with vessels.

B-cell follicles sit in the cortex. A secondary follicle has a germinal centre (proliferating B cells, follicular dendritic cells, tingible-body macrophages) and a mantle. T cells dominate the paracortex, which also holds high endothelial venules — the entry door from blood.

Medullary cords have plasma cells and macrophages. Sinuses are the lymph channels lined by discontinuous endothelium and macrophages — the filter.

Spleen has white pulp and red pulp. White pulp is lymphoid: PALS (T cells around a central arteriole) and follicles (B cells). Red pulp is cords and sinusoids that screen RBCs. A spleen without a proper capsule barrier still has a connective-tissue framework of trabeculae.

Thymus is where T cells mature. Cortex is dense with thymocytes; medulla is paler and contains Hassall’s corpuscles — epithelial swirls unique to thymus. The thymus is an epithelial organ with lymphoid guests, not a typical lymph node.

MALT includes tonsils, Peyer’s patches, and appendix. Tonsils have crypts lined by stratified squamous (palatine) or other epithelium depending on site. Peyer’s patches in ileum have M cells over the dome that sample gut antigen.

Clinical: tender nodes in infection, hard fixed nodes in metastasis, splenomegaly patterns, thymoma in the anterior mediastinum. If asked “where do T cells mature?”, the answer is thymus, not node.
''',
    ),
    BookChapter(
      id: 'h13',
      title: 'Heart and vessels',
      subtitle: 'From endothelium to elastic artery',
      body: '''
The inner lining of the whole vascular tree is endothelium: simple squamous epithelium on a basement membrane. It is not wallpaper. It controls clotting, tone, and leukocyte traffic.

Vessel wall layers: tunica intima (endothelium + internal elastic lamina in arteries), tunica media (smooth muscle ± elastic lamellae), tunica adventitia (collagen, vasa vasorum, nerves).

Elastic arteries (aorta, pulmonary trunk) have many elastic lamellae in the media. They smooth the pulse. Age and hypertension change this wall.

Muscular arteries have a clear internal elastic lamina and a media of smooth muscle. They distribute and control flow.

Arterioles have one to three muscle layers and are the main resistance vessels. Capillaries are endothelium plus pericytes. Venules collect; veins have thinner walls, larger lumens, and valves in the limbs.

Capillary types: continuous (muscle, brain), fenestrated (gut, kidney glomerulus, endocrine), discontinuous / sinusoids (liver, marrow, spleen). Match the leakiness to the organ’s job.

Heart wall: endocardium (endothelium + connective tissue + Purkinje in ventricles), myocardium, epicardium (visceral pericardium with fat and coronaries). Valves are endocardial folds with a dense collagen core — they are avascular in the leaflets, which matters for healing and endocarditis.

Atherosclerosis begins as intimal lipid and inflammatory change in large elastic and muscular arteries. Aneurysm is a wall that can no longer hold pressure. Varicose veins are failed valves plus thin walls.

If a slide shows a round vessel with a thick media, call artery. If the wall is thin and the lumen floppy, call vein. If only a single endothelial tube with RBCs in a row, call capillary.
''',
    ),
    BookChapter(
      id: 'h14',
      title: 'Skin',
      subtitle: 'Epidermis, dermis, and appendages',
      body: '''
Skin is a barrier, a sensor, a temperature controller, and a vitamin D factory.

Epidermis is keratinised stratified squamous epithelium. Layers from deep to superficial: stratum basale, spinosum, granulosum, (lucidum in thick skin), corneum. Basale holds stem cells and melanocytes. Spinosum has desmosomes that look like spines. Granulosum has keratohyalin. Corneum is dead, packed keratin.

Thick skin (palm, sole) has no hair and a thick corneum and lucidum. Thin skin has hair follicles and a thinner epidermis.

Dermis: papillary layer is loose connective tissue with capillaries and Meissner corpuscles. Reticular layer is dense irregular connective tissue with larger vessels, nerves, and glands.

Hypodermis (subcutis) is fat and loose connective tissue — the padding and insulation.

Appendages: hair follicles, sebaceous glands (holocrine, attached to follicles), eccrine sweat glands (merocrine, thermoregulation, palmoplantar density high), apocrine glands (axilla, groin, open into follicles).

Nails sit on a nail bed of epidermis. The matrix makes the plate.

Cells besides keratinocytes: melanocytes (basal layer, pigment donation), Langerhans cells (immune, spinosum), Merkel cells (touch, basal). Melanin amount and packaging, not melanocyte count, mainly decide colour.

Clinical: burns are classified by depth through these layers. Blistering diseases split epidermis at different levels. Basal-cell and squamous-cell carcinoma are keratinocyte tumours with different behaviour. Melanoma is melanocyte malignancy — thickness still drives talk at the microscope.
''',
    ),
    BookChapter(
      id: 'h15',
      title: 'High-yield viva points',
      subtitle: 'Rapid revision before a slide or table viva',
      body: '''
Name the four basic tissues without hesitation: epithelium, connective tissue, muscle, nerve.

Simple squamous locations: alveoli, endothelium, mesothelium. Do not mix them up — function is exchange or frictionless lining.

Respiratory epithelium: pseudostratified ciliated columnar with goblet cells. Olfactory epithelium is different: no goblet cells, has bipolar neurons.

Urothelium is transitional, with umbrella cells, in renal pelvis to urethra (part).

Tendon is dense regular connective tissue. Dermis is dense irregular. Lymph node reticulum is type III collagen.

Cartilage is avascular; bone is vascular. That is why cartilage heals slowly and bone remodels.

Growth plate order: resting, proliferative, hypertrophic, calcification, ossification.

Skeletal muscle nuclei are peripheral; cardiac and smooth are central. Intercalated discs mean heart.

CNS myelin: oligodendrocyte. PNS myelin: Schwann cell. Hassall’s corpuscles mean thymus.

RBC diameter is your built-in scale: about 7–8 micrometres.

Goblet cell: unicellular mucous gland. Plasma cell: clock-face nucleus, Golgi halo, antibody factory.

When you do not know the organ, describe honestly: lining epithelium, presence of glands, muscle layers, lymphoid tissue, special structures. Examiners often mark a clean description higher than a wild guess.

Highlight the lines you keep missing. Those rose marks are your personal viva list.
''',
    ),
  ];
}
