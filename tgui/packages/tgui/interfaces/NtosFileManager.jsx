import { useBackend } from '../backend';
import { Button, Section, Table } from '../components';
import { NtosWindow } from '../layouts';

export const NtosFileManager = (props) => {
  const { act, data } = useBackend();
  const { PC_device_theme, usbconnected, files = [], usbfiles = [] } = data;
  return (
    <NtosWindow theme={PC_device_theme}>
      <NtosWindow.Content scrollable>
        <Section>
          <FileTable
            files={files}
            usbconnected={usbconnected}
            onUpload={(file) => act('PRG_copytousb', { name: file })}
            onDelete={(file) => act('PRG_deletefile', { name: file })}
            onRename={(file, newName) =>
              act('PRG_renamefile', {
                name: file,
                new_name: newName,
              })
            }
            onDuplicate={(file) => act('PRG_clone', { file: file })}
            onToggleSilence={(file) => act('PRG_togglesilence', { name: file })}
          />
        </Section>
        {usbconnected && (
          <Section title="Data Disk">
            <FileTable
              usbmode
              files={usbfiles}
              usbconnected={usbconnected}
              onUpload={(file) => act('PRG_copyfromusb', { name: file })}
              onDelete={(file) => act('PRG_usbdeletefile', { name: file })}
              onRename={(file, newName) =>
                act('PRG_usbrenamefile', {
                  name: file,
                  new_name: newName,
                })
              }
              onDuplicate={(file) => act('PRG_clone', { file: file })}
            />
          </Section>
        )}
      </NtosWindow.Content>
    </NtosWindow>
  );
};

const FileTable = (props) => {
  const {
    files = [],
    usbconnected,
    usbmode,
    onUpload,
    onDelete,
    onRename,
    onToggleSilence,
  } = props;
  return (
    <Table>
      <Table.Row header>
        <Table.Cell>File</Table.Cell>
        <Table.Cell collapsing>Type</Table.Cell>
        <Table.Cell collapsing>Size</Table.Cell>
        <Table.Cell collapsing>Actions</Table.Cell>
      </Table.Row>
      {files.map((file) => (
        <Table.Row key={file.name} className="candystripe">
          <Table.Cell fluid>
            {!file.undeletable ? (
              <Button.Input
                fluid
                verticalFluid
                content={file.name}
                currentValue={file.name}
                tooltip="Rename"
                onCommit={(e, value) => onRename(file.name, value)}
              />
            ) : (
              file.name
            )}
          </Table.Cell>
          <Table.Cell>{file.type}</Table.Cell>
          <Table.Cell>{file.size}</Table.Cell>
          <Table.Cell collapsing fluid>
            {!!file.alert_able && (
              <Button
                verticalFluid
                buttonList
                icon={file.alert_silenced ? 'bell-slash' : 'bell'}
                color={file.alert_silenced ? 'red' : 'default'}
                tooltip={file.alert_silenced ? 'Unmute Alerts' : 'Mute Alerts'}
                onClick={() => onToggleSilence(file.name)}
              />
            )}
            {!file.undeletable && (
              <>
                <Button.Confirm
                  verticalFluid
                  buttonList
                  icon="trash"
                  confirmIcon="times"
                  confirmContent=""
                  tooltip="Delete"
                  onClick={() => onDelete(file.name)}
                />
                {!!usbconnected &&
                  (usbmode ? (
                    <Button
                      verticalFluid
                      buttonList
                      icon="download"
                      tooltip="Download"
                      onClick={() => onUpload(file.name)}
                    />
                  ) : (
                    <Button
                      verticalFluid
                      buttonList
                      icon="upload"
                      tooltip="Upload"
                      onClick={() => onUpload(file.name)}
                    />
                  ))}
              </>
            )}
          </Table.Cell>
        </Table.Row>
      ))}
    </Table>
  );
};
