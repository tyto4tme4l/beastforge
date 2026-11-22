import { FieldName } from './types';

type AttributeName = string;

export const numberFields: FieldName[] = [
  'id',
  'width',
  'height',
  'aspect_ratio',
  'comment_count',
  'score',
  'upvotes',
  'downvotes',
  'legacy_score',
  'legacy_upvotes',
  'legacy_downvotes',
  'legacy_faves',
  'faves',
  'tag_count',
  'score',
];

export const dateFields: FieldName[] = ['created_at'];

export const literalFields = ['tags', 'orig_sha512_hash', 'sha512_hash', 'uploader', 'source_url', 'legacy_source', 'description'];

export const termSpaceToImageField: Record<FieldName, AttributeName> = {
  tags: 'data-image-tag-aliases',
  score: 'data-score',
  upvotes: 'data-upvotes',
  downvotes: 'data-downvotes',
  legacy_score: 'data-legacy-score',
  legacy_upvotes: 'data-legacy-upvotes',
  legacy_downvotes: 'data-legacy-downvotes',
  legacy_faves: 'data-legacy-faves',
  legacy_source: 'data-legacy-source',
  uploader: 'data-uploader',
  // Yeah, I don't think this is reasonably supportable.
  // faved_by: 'data-faved-by',
  id: 'data-image-id',
  width: 'data-width',
  height: 'data-height',
  /* eslint-disable camelcase */
  aspect_ratio: 'data-aspect-ratio',
  comment_count: 'data-comment-count',
  tag_count: 'data-tag-count',
  source_url: 'data-source-url',
  faves: 'data-faves',
  sha512_hash: 'data-sha512',
  orig_sha512_hash: 'data-orig-sha512',
  created_at: 'data-created-at',
  /* eslint-enable camelcase */
};

export const defaultField = 'tags';
