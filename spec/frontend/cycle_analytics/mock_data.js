import { getJSONFixture } from 'helpers/fixtures';
import { TEST_HOST } from 'helpers/test_constants';
import { DEFAULT_VALUE_STREAM, DEFAULT_DAYS_IN_PAST } from '~/cycle_analytics/constants';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { getDateInPast } from '~/lib/utils/datetime_utility';

export const createdBefore = new Date(2019, 0, 14);
export const createdAfter = getDateInPast(createdBefore, DEFAULT_DAYS_IN_PAST);

export const deepCamelCase = (obj) => convertObjectPropsToCamelCase(obj, { deep: true });

export const getStageByTitle = (stages, title) =>
  stages.find((stage) => stage.title && stage.title.toLowerCase().trim() === title) || {};

const fixtureEndpoints = {
  customizableCycleAnalyticsStagesAndEvents: 'projects/analytics/value_stream_analytics/stages',
  stageEvents: (stage) => `projects/analytics/value_stream_analytics/events/${stage}`,
};

export const customizableStagesAndEvents = getJSONFixture(
  fixtureEndpoints.customizableCycleAnalyticsStagesAndEvents,
);

export const defaultStages = ['issue', 'plan', 'review', 'code', 'test', 'staging'];

const stageFixtures = defaultStages.reduce((acc, stage) => {
  const events = getJSONFixture(fixtureEndpoints.stageEvents(stage));
  return {
    ...acc,
    [stage]: events,
  };
}, {});

export const summary = [
  { value: '20', title: 'New Issues' },
  { value: null, title: 'Commits' },
  { value: null, title: 'Deploys' },
  { value: null, title: 'Deployment Frequency', unit: 'per day' },
];

export const issueStage = {
  id: 'issue',
  title: 'Issue',
  name: 'issue',
  legend: '',
  description: 'Time before an issue gets scheduled',
  value: null,
};

export const planStage = {
  id: 'plan',
  title: 'Plan',
  name: 'plan',
  legend: '',
  description: 'Time before an issue starts implementation',
  value: 75600,
};

export const codeStage = {
  id: 'code',
  title: 'Code',
  name: 'code',
  legend: '',
  description: 'Time until first merge request',
  value: 172800,
};

export const testStage = {
  id: 'test',
  title: 'Test',
  name: 'test',
  legend: '',
  description: 'Total test time for all commits/merges',
  value: 17550,
};

export const reviewStage = {
  id: 'review',
  title: 'Review',
  name: 'review',
  legend: '',
  description: 'Time between merge request creation and merge/close',
  value: null,
};

export const stagingStage = {
  id: 'staging',
  title: 'Staging',
  name: 'staging',
  legend: '',
  description: 'From merge request merge until deploy to production',
  value: 172800,
};

export const selectedStage = {
  ...issueStage,
  value: null,
  active: false,
  isUserAllowed: true,
  emptyStageText:
    'The issue stage shows the time it takes from creating an issue to assigning the issue to a milestone, or add the issue to a list on your Issue Board. Begin creating issues to see data for this stage.',

  slug: 'issue',
};

export const stats = [issueStage, planStage, codeStage, testStage, reviewStage, stagingStage];

export const permissions = {
  issue: true,
  plan: true,
  code: true,
  test: true,
  review: true,
  staging: true,
};

export const rawData = {
  summary,
  stats,
  permissions,
};

export const convertedData = {
  summary: [
    { value: '20', title: 'New Issues' },
    { value: '-', title: 'Commits' },
    { value: '-', title: 'Deploys' },
    { value: '-', title: 'Deployment Frequency', unit: 'per day' },
  ],
};

export const rawIssueEvents = stageFixtures.issue;
export const issueEvents = deepCamelCase(rawIssueEvents);
export const planEvents = deepCamelCase(stageFixtures.plan);
export const reviewEvents = deepCamelCase(stageFixtures.review);
export const codeEvents = deepCamelCase(stageFixtures.code);
export const testEvents = deepCamelCase(stageFixtures.test);
export const stagingEvents = deepCamelCase(stageFixtures.staging);

export const pathNavIssueMetric = 172800;

export const rawStageMedians = [
  { id: 'issue', value: 172800 },
  { id: 'plan', value: 86400 },
  { id: 'review', value: 1036800 },
  { id: 'code', value: 129600 },
  { id: 'test', value: 259200 },
  { id: 'staging', value: 388800 },
];

export const stageMedians = {
  issue: 172800,
  plan: 86400,
  review: 1036800,
  code: 129600,
  test: 259200,
  staging: 388800,
};

export const formattedStageMedians = {
  issue: '2d',
  plan: '1d',
  review: '1w',
  code: '1d',
  test: '3d',
  staging: '4d',
};

export const allowedStages = [issueStage, planStage, codeStage];

export const transformedProjectStagePathData = [
  {
    metric: 172800,
    selected: true,
    stageCount: undefined,
    icon: null,
    id: 'issue',
    title: 'Issue',
    name: 'issue',
    legend: '',
    description: 'Time before an issue gets scheduled',
    value: null,
  },
  {
    metric: 86400,
    selected: false,
    stageCount: undefined,
    icon: null,
    id: 'plan',
    title: 'Plan',
    name: 'plan',
    legend: '',
    description: 'Time before an issue starts implementation',
    value: 75600,
  },
  {
    metric: 129600,
    selected: false,
    stageCount: undefined,
    icon: null,
    id: 'code',
    title: 'Code',
    name: 'code',
    legend: '',
    description: 'Time until first merge request',
    value: 172800,
  },
];

export const selectedValueStream = DEFAULT_VALUE_STREAM;

export const group = {
  id: 1,
  name: 'foo',
  path: 'foo',
  full_path: 'foo',
  avatar_url: `${TEST_HOST}/images/home/nasa.svg`,
};

export const currentGroup = convertObjectPropsToCamelCase(group, { deep: true });

export const selectedProjects = [
  {
    id: 'gid://gitlab/Project/1',
    name: 'cool project',
    pathWithNamespace: 'group/cool-project',
    avatarUrl: null,
  },
  {
    id: 'gid://gitlab/Project/2',
    name: 'another cool project',
    pathWithNamespace: 'group/another-cool-project',
    avatarUrl: null,
  },
];

export const rawValueStreamStages = customizableStagesAndEvents.stages;

export const valueStreamStages = rawValueStreamStages.map((s) =>
  convertObjectPropsToCamelCase(s, { deep: true }),
);
