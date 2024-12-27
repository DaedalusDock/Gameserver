/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { classes } from 'common/react';

import { computeBoxClassName, computeBoxProps } from '../components/Box';

export const Layout = (props) => {
  const { className, theme = 'crtyellow', children, ...rest } = props;
  return (
    <div className={'theme-' + theme}>
      <div
        className={classes(['Layout', className, ...computeBoxClassName(rest)])}
        {...computeBoxProps(rest)}
      >
        {children}
      </div>
    </div>
  );
};

const LayoutContent = (props) => {
  const { className, scrollable, children, ...rest } = props;
  return (
    <div
      className={classes([
        'Layout__content',
        scrollable && 'Layout__content--scrollable',
        className,
        ...computeBoxClassName(rest),
      ])}
      {...computeBoxProps(rest)}
    >
      {children}
    </div>
  );
};

Layout.Content = LayoutContent;
