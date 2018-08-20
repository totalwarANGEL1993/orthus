package twa.siedelwood.s5.questeditor.extern;

import java.io.File;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Comparator;
import org.apache.commons.lang.SystemUtils;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class MapFileManager
{
	protected String mapPath;

    protected boolean isWindows() {
		return SystemUtils.IS_OS_WINDOWS;
	}
	
	protected String buildExecutionString(final String path) {
	    String exec = System.getProperty("user.dir") + "\\bin\\bba5.exe " + path + "";
		if (!isWindows()) {
			exec = System.getProperty("user.dir") + "/bin/bba5.sh " + path;
		}
		return exec;
	}

	protected void execute() throws MapFileManagerException {
        try {
            System.out.println("Processing map...");

            final Process process = Runtime.getRuntime().exec(buildExecutionString(mapPath));
            final InputStream is = process.getInputStream();

            int size = 0;
            final byte[] buffer = new byte[1024];
            while ((size = is.read(buffer)) != -1)
			{
				System.out.write(buffer, 0, size);
			}

            process.waitFor();

            System.out.println("Done!");
        }
        catch(final Exception e) {
            throw new MapFileManagerException(e);
        }
    }
	
	public boolean packMap() throws MapFileManagerException {
        final File result = new File(mapPath.substring(0, mapPath.length()-9));
        try {
            System.out.println(result.getPath());
            if (result.exists()) {
                System.out.println("Deleting old version...");
                Files.delete(Paths.get(result.getAbsolutePath()));
                System.out.println("Done!");
            }
        }
        catch (final Exception e) {
            throw new MapFileManagerException(e);
        }

        final File f = new File(mapPath);
        if (!f.exists() || !f.isDirectory()) {
            throw new MapFileManagerException("Could not pack map: " + mapPath);
        }
        execute();
        return result.exists();
	}
	
	public boolean unpackMap() throws MapFileManagerException {
        final File result = new File(mapPath + ".unpacked");
        try {
            System.out.println("Deleting unpacked...");
            if (result.exists()) {
                Files.walk(Paths.get(result.getAbsolutePath()))
                        .sorted(Comparator.reverseOrder())
                        .map(Path::toFile)
                        .peek(System.out::println)
                        .forEach(File::delete);
            }
            System.out.println("Done!");
        }
        catch (final Exception e) {
            throw new MapFileManagerException(e);
        }

        final File f = new File(mapPath);
        if (!f.exists() || f.isDirectory()) {
            throw new MapFileManagerException("Could not unpack map: " + mapPath);
        }
	    execute();
	    return result.exists();
	}

    public boolean add(final String source, String dest) throws MapFileManagerException {
        dest = (dest == null) ? "" : dest;
        final File destFile = new File(mapPath + "/" + dest);
        final File sourceFile = new File(source);

        destFile.mkdirs();
        try {
            final Path sourcePath = Paths.get(source);
            final Path destPath = Paths.get(destFile.getAbsolutePath());
            destPath.toFile().delete();
            System.out.println("copy " + sourcePath + " " + destPath);
            Files.copy(sourcePath, destPath);
        } catch (final Exception e) {
            throw new MapFileManagerException(e);
        }
        return true;
    }

    public boolean add(final InputStream source, String dest) throws MapFileManagerException {
        dest = (dest == null) ? "" : dest;
        final File destFile = new File(mapPath + "/" + dest);

        destFile.mkdirs();
        try {
            final Path destPath = Paths.get(destFile.getAbsolutePath());
            destPath.toFile().delete();
            System.out.println("copy stream to " + destPath);
            Files.copy(source, destPath);
        } catch (final Exception e) {
            throw new MapFileManagerException(e);
        }
        return true;
    }
}
