import { Antagonist, Category } from '../base';

const Changeling: Antagonist = {
  key: 'changeling',
  name: 'Changeling',
  description: [
    `
      A highly intelligent alien predator that is capable of altering their
      shape to flawlessly resemble a human.
    `,

    `
      Transform yourself or others into different identities, and buy from an
      arsenal of biological weaponry with the DNA you collect.
    `,
  ],
  category: Category.Roundstart,
};

export default Changeling;
