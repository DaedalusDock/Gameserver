import { map } from 'common/collections';

import { useBackend } from '../backend';
import { Button, Section, Table } from '../components';
import { NtosWindow } from '../layouts';

// PARIAH EDIT
//
// width={500} - Original: width={400}
//
// Original: entry.rank
// {entry.rank === entry.trim ? entry.rank : <>{entry.rank} ({entry.trim})</>}

export const NtosCrewManifest = (props) => {
  const { act, data } = useBackend();
  const { have_printer, manifest = {}, PC_device_theme, manifest_key } = data;
  return (
    <NtosWindow width={500} height={480} theme={PC_device_theme}>
      <NtosWindow.Content scrollable>
        <Section
          title="Staff Manifest"
          buttons={
            <Button
              icon="print"
              content="Print"
              disabled={!have_printer}
              onClick={() => act('PRG_print')}
            />
          }
        >
          {(!!manifest_key &&
            map((entries, department) => (
              <Section key={department} level={2} title={department}>
                <Table>
                  {entries.map((entry) => (
                    <Table.Row key={entry.name} className="candystripe">
                      <Table.Cell bold>{entry.name}</Table.Cell>
                      <Table.Cell>
                        {entry.rank === entry.trim ? (
                          entry.rank
                        ) : (
                          <>
                            {entry.rank} ({entry.trim})
                          </>
                        )}
                      </Table.Cell>
                    </Table.Row>
                  ))}
                </Table>
              </Section>
            ))(manifest)) ||
            'ERROR - NO IDENTIFICATION FOUND.'}
        </Section>
      </NtosWindow.Content>
    </NtosWindow>
  );
};
