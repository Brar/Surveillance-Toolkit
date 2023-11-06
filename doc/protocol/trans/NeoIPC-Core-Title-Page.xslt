<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns="http://www.w3.org/2000/svg" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xlink="http://www.w3.org/1999/xlink">
    <xsl:output
        method="xml"
        version="1.0"
        encoding="UTF-8"
        doctype-public="-//W3C//DTD SVG 1.1//EN"
        doctype-system="http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"
        indent="yes"
        cdata-section-elements="style"
    />
    <xsl:template match="/">
        <svg version="1.1" viewBox="0 0 21000 29700">
            <style type="text/css">
                <![CDATA[
                    text { font-family: Noto Serif, serif; }
                ]]>
            </style>
            <symbol id="flag" viewBox="0 0 1580 1080">
                <rect width="1580" height="1080" fill="#FFF"/>
                <rect x="40" y="40" width="1500" height="1000" fill="#039"/>
                <polygon fill="#FC0" points="956.6666666666666,195.76930984963155 989.3214029051373,296.2702539815731 903.8301935391581,234.15725460657893 1009.5031397941751,234.1572546065789 924.0119304281959,296.2702539815731"/>
                <polygon fill="#FC0" points="1078.6751345948128,317.7777777777777 1111.3298708332836,418.27872190971925 1025.8386614673043,356.1657225347251 1131.5116077223213,356.16572253472503 1046.020398356342,418.27872190971925"/>
                <polygon fill="#FC0" points="1123.3333333333333,484.44444444444446 1155.988069571804,584.945388576386 1070.4968602058248,522.8323892013918 1176.1698064608418,522.8323892013918 1090.6785970948627,584.945388576386"/>
                <polygon fill="#FC0" points="1078.6751345948128,651.111111111111 1111.3298708332836,751.6120552430525 1025.8386614673043,689.4990558680583 1131.5116077223213,689.4990558680583 1046.020398356342,751.6120552430525"/>
                <polygon fill="#FC0" points="956.6666666666666,773.1195790392574 989.3214029051373,873.6205231711989 903.8301935391581,811.5075237962047 1009.5031397941751,811.5075237962047 924.0119304281959,873.6205231711989"/>
                <polygon fill="#FC0" points="790,817.7777777777777 822.6547362384707,918.2787219097193 737.1635268724915,856.1657225347251 842.8364731275085,856.1657225347251 757.3452637615293,918.2787219097193"/>
                <polygon fill="#FC0" points="623.3333333333333,773.1195790392572 655.988069571804,873.6205231711988 570.4968602058248,811.5075237962046 676.1698064608418,811.5075237962046 590.6785970948625,873.6205231711988"/>
                <polygon fill="#FC0" points="501.32486540518727,651.1111111111112 533.979601643658,751.6120552430527 448.4883922776787,689.4990558680586 554.1613385326958,689.4990558680586 468.67012916671655,751.6120552430527"/>
                <polygon fill="#FC0" points="456.6666666666667,484.44444444444457 489.3214029051374,584.9453885763861 403.83019353915813,522.832389201392 509.50313979417524,522.832389201392 424.01193042819597,584.9453885763861"/>
                <polygon fill="#FC0" points="501.3248654051872,317.7777777777778 533.9796016436579,418.27872190971937 448.48839227767866,356.1657225347252 554.1613385326957,356.16572253472515 468.6701291667165,418.27872190971937"/>
                <polygon fill="#FC0" points="623.3333333333333,195.76930984963172 655.988069571804,296.27025398157326 570.4968602058248,234.1572546065791 676.1698064608418,234.15725460657907 590.6785970948625,296.27025398157326"/>
                <polygon fill="#FC0" points="789.9999999999999,151.1111111111112 822.6547362384706,251.6120552430527 737.1635268724914,189.49905586805858 842.8364731275084,189.49905586805855 757.3452637615292,251.61205524305274"/>
            </symbol>


            <xsl:if test="root/data[@name='translated_by']/value">
                <text x="20000" y="25000" font-size="400px" font-style="italic" text-anchor="end">
                    <xsl:value-of select="root/data[@name='translated_by']/value"/>
                </text>
            </xsl:if> 
            <rect fill="white" stroke="black" x="1000" y="25200" width="19000" height="3500" />
            <text x="1500" y="26000" font-size="500px" font-weight="bold">
                <xsl:value-of select="root/data[@name='neoipc_project']/value"/>
            </text>
            <text x="1500" y="26600" font-size="400px" fill="#0083C1">https://neoipc.org</text>
            <use xlink:href="#flag" x="1380" y="27300" width="1580" height="1080"/>
            <text x="3500" y="27700" font-size="350px">
                <xsl:call-template name="split_long_text">
                    <xsl:with-param name="text" select="root/data[@name='funding_statement']/value/text()"/>
                    <xsl:with-param name="maxLen" select="96"/>
                    <xsl:with-param name="x" select="3300"/>
                    <xsl:with-param name="first_dy" select="0"/>
                    <xsl:with-param name="further_dy" select="420"/>
                </xsl:call-template>
            </text>
        </svg>
    </xsl:template>
    <xsl:template name="split_long_text">
        <xsl:param name="text" select="."/>
        <xsl:param name="separator" select="' '"/>
        <xsl:param name="maxLen"/>
        <xsl:param name="x"/>
        <xsl:param name="first_dy"/>
        <xsl:param name="further_dy"/>
        <xsl:param name="previous"/>
        <xsl:choose>
            <xsl:when test="(string-length($previous) &gt; 0) and not(contains($text, $separator)) and (string-length(concat($previous, ' ', $text)) &lt; $maxLen)">
                <tspan x="{$x}" dy="{$first_dy}"><xsl:value-of select="concat($previous, ' ', $text)"/></tspan>
            </xsl:when>
            <xsl:when test="(string-length($previous) &gt; 0) and not(contains($text, $separator))">
                <tspan x="{$x}" dy="{$first_dy}"><xsl:value-of select="$previous"/></tspan>
                <tspan x="{$x}" dy="{$further_dy}"><xsl:value-of select="$text"/></tspan>
            </xsl:when>
            <xsl:when test="(string-length($previous) &gt; 0) and (string-length(concat($previous, ' ', substring-before($text, $separator))) &lt; $maxLen)">
                <xsl:call-template name="split_long_text">
                    <xsl:with-param name="text" select="substring-after($text, $separator)"/>
                    <xsl:with-param name="separator" select="$separator"/>
                    <xsl:with-param name="maxLen" select="$maxLen"/>
                    <xsl:with-param name="x" select="$x"/>
                    <xsl:with-param name="first_dy" select="$first_dy"/>
                    <xsl:with-param name="further_dy" select="$further_dy"/>
                    <xsl:with-param name="previous" select="concat($previous, ' ', substring-before($text, $separator))"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="string-length($previous) &gt; 0">
                <tspan x="{$x}" dy="{$first_dy}"><xsl:value-of select="$previous"/></tspan>
                <xsl:call-template name="split_long_text">
                    <xsl:with-param name="text" select="substring-after($text, $separator)"/>
                    <xsl:with-param name="separator" select="$separator"/>
                    <xsl:with-param name="maxLen" select="$maxLen"/>
                    <xsl:with-param name="x" select="$x"/>
                    <xsl:with-param name="first_dy" select="$further_dy"/>
                    <xsl:with-param name="further_dy" select="$further_dy"/>
                    <xsl:with-param name="previous" select="substring-before($text, $separator)"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="not(contains($text, $separator)) or (string-length(substring-before($text, $separator)) &gt; $maxLen)">
                <tspan x="{$x}" dy="{$first_dy}"><xsl:value-of select="$text"/></tspan>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="split_long_text">
                    <xsl:with-param name="text" select="substring-after($text, $separator)"/>
                    <xsl:with-param name="separator" select="$separator"/>
                    <xsl:with-param name="maxLen" select="$maxLen"/>
                    <xsl:with-param name="x" select="$x"/>
                    <xsl:with-param name="first_dy" select="$first_dy"/>
                    <xsl:with-param name="further_dy" select="$further_dy"/>
                    <xsl:with-param name="previous" select="substring-before($text, $separator)"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
