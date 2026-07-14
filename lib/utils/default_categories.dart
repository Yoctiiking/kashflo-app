// Valeurs de départ copiées dans le profil de chaque nouvel utilisateur.
// Une fois créées, les catégories vivent dans users/{uid}.expenseCategories
// et .incomeCategories — cette liste ne sert plus que de valeur initiale et
// de repli si le champ est absent (comptes créés avant cette fonctionnalité).
// Aligné sur lib/categories.ts côté web.
const kDefaultExpenseCategories = [
  'Alimentation',
  'Transport',
  'Logement',
  'Santé',
  'Loisirs',
  'Vêtements',
  'Abonnements',
  'Restaurants',
  'Éducation',
  'Autre',
];

const kDefaultIncomeCategories = [
  'Salaire',
  'Freelance',
  'Investissements',
  'Remboursement',
  'Autre',
];
